# Windows PowerShell 5.1 / PowerShell 7. No server credentials are distributed.
[CmdletBinding()]
param(
    [ValidateSet('setup', 'doctor', 'run', 'build', 'pack')]
    [string]$Action = 'doctor',
    [string]$Bundle,
    [string]$DeviceId,
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$teamRoot = Join-Path $repoRoot '.team'
$teamPackage = 'com.example.tui_khon_mobile.team'
$utf8 = [System.Text.UTF8Encoding]::new($false)
$previousTeamMode = [Environment]::GetEnvironmentVariable('TUI_KHON_TEAM', 'Process')
$bundleFiles = @('.env.team', 'signing.properties', 'team-debug.jks', 'manifest.json')

function Read-Settings([string]$Path) {
    $result = @{}
    foreach ($line in [IO.File]::ReadAllLines($Path)) {
        if ($line -match '^([A-Z_a-z][A-Z_a-z0-9]*)=(.*)$') {
            $result[$Matches[1]] = $Matches[2].Trim().Trim('"').Trim("'")
        }
    }
    return $result
}

function Write-Utf8([string]$Path, [string]$Content) {
    [IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Invoke-Checked([string]$File, [string[]]$Arguments) {
    & $File @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Command failed ($LASTEXITCODE): $(Split-Path -Leaf $File) $($Arguments[0]). See output above." }
}

function Assert-ClientConfig([hashtable]$Config) {
    $allowed = @('SUPABASE_URL','SUPABASE_ANON_KEY','GOOGLE_WEB_CLIENT_ID','GOOGLE_IOS_CLIENT_ID')
    foreach ($key in $Config.Keys) {
        if ($key -notin $allowed) { throw "Team Flutter configuration contains an unexpected key: $key" }
    }
    $uri = $null
    if (-not [Uri]::TryCreate($Config.SUPABASE_URL, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https' -or $uri.UserInfo) {
        throw 'Team backend must be an HTTPS cloud URL.'
    }
    $keyValue = [string]$Config.SUPABASE_ANON_KEY
    $isPublic = $keyValue -match '^sb_publishable_[A-Za-z0-9_-]+$'
    if (-not $isPublic -and $keyValue -match '^eyJ[^.]+\.[^.]+\.[^.]+$') {
        try {
            $payload = $keyValue.Split('.')[1].Replace('-','+').Replace('_','/')
            $payload = $payload.PadRight($payload.Length + ((4 - $payload.Length % 4) % 4), '=')
            $claims = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json
            $isPublic = $claims.role -eq 'anon'
        } catch { $isPublic = $false }
    }
    if (-not $isPublic) { throw 'Only a Supabase publishable key or legacy anon key is allowed. Secret/service-role keys are rejected.' }
    if ($Config.GOOGLE_WEB_CLIENT_ID -notmatch '^\d+-[a-z0-9]+\.apps\.googleusercontent\.com$') {
        throw 'A real Google Web client ID is required in the Team bundle.'
    }
    if ($Config.GOOGLE_IOS_CLIENT_ID) { throw 'This Team bundle is Android-only; GOOGLE_IOS_CLIENT_ID must be empty.' }
}

function Find-Flutter {
    $command = Get-Command flutter -ErrorAction SilentlyContinue
    if (-not $command) { throw 'Flutter not found. Install Flutter 3.47.7, add its bin folder to PATH, then open a new terminal.' }
    $script:flutter = $command.Source
    $versionText = (& $script:flutter --version --machine | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'Flutter could not start. Run flutter doctor -v.' }
    $versionInfo = $versionText | ConvertFrom-Json
    $version = [version]($versionInfo.frameworkVersion -replace '-.*$', '')
    $dartVersion = [version](($versionInfo.dartSdkVersion -split ' ')[0] -replace '-.*$', '')
    if ($version -lt [version]'3.47.0' -or $dartVersion -lt [version]'3.13.0' -or $dartVersion -ge [version]'4.0.0') {
        throw 'This lockfile requires Flutter >=3.47 and Dart >=3.13,<4. Use the tested Flutter 3.47.7.'
    }
    if ($versionInfo.frameworkVersion -ne '3.47.7') { Write-Warning 'Tested SDK: Flutter 3.47.7. Your compatible SDK may resolve/build differently; do not run pub upgrade.' }
    Write-Host "Flutter $($versionInfo.frameworkVersion) / Dart $($versionInfo.dartSdkVersion)"
}

function Find-AndroidTools {
    $doctor = (& $script:flutter doctor -v | Out-String) -replace '\x1B\[[0-?]*[ -/]*[@-~]', ''
    if ($doctor -match 'Android license status unknown|licenses not accepted|cmdline-tools component is missing|Unable to locate Android SDK') {
        throw 'Android SDK/licenses are incomplete. Run flutter doctor -v, install the listed SDK tools, and personally accept licenses with flutter doctor --android-licenses.'
    }
    $sdk = $env:ANDROID_HOME
    if (-not $sdk) { $sdk = $env:ANDROID_SDK_ROOT }
    if (-not $sdk -and $doctor -match 'Android SDK at ([^\r\n]+)') { $sdk = $Matches[1].Trim() }
    if (-not $sdk) { $sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
    if (-not (Test-Path -LiteralPath (Join-Path $sdk 'platform-tools\adb.exe'))) {
        throw 'Android SDK platform-tools not found. Configure the SDK in Android Studio and run flutter doctor -v.'
    }
    $script:adb = Join-Path $sdk 'platform-tools\adb.exe'
    $java = $null
    if ($doctor -match 'Java binary at: ([^\r\n]+)') { $java = $Matches[1].Trim() }
    $keytoolCommand = Get-Command keytool -ErrorAction SilentlyContinue
    if ($java -and (Test-Path -LiteralPath (Join-Path (Split-Path -Parent $java) 'keytool.exe'))) {
        $script:keytool = Join-Path (Split-Path -Parent $java) 'keytool.exe'
    } elseif ($keytoolCommand) { $script:keytool = $keytoolCommand.Source
    } else { throw 'JDK keytool not found. Configure Android Studio/JDK for Flutter; see flutter doctor -v.' }
}

function Get-SigningSha1([string]$Directory) {
    $settings = Read-Settings (Join-Path $Directory 'signing.properties')
    if ($settings.keyAlias -ne 'tui-khon-team-dev' -or -not $settings.storePassword -or -not $settings.keyPassword) {
        throw 'Invalid Team signing configuration.'
    }
    $oldPassword = [Environment]::GetEnvironmentVariable('TUI_KHON_KEYSTORE_PASSWORD','Process')
    try {
        $env:TUI_KHON_KEYSTORE_PASSWORD = $settings.storePassword
        $oldErrorPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue' # PowerShell 5.1 wraps keytool's stderr warnings as ErrorRecords.
        try { $output = (& $script:keytool '-J-Duser.language=en' -list -v -keystore (Join-Path $Directory 'team-debug.jks') -alias $settings.keyAlias '-storepass:env' TUI_KHON_KEYSTORE_PASSWORD 2>&1 | Out-String); $keyExit = $LASTEXITCODE }
        finally { $ErrorActionPreference = $oldErrorPreference }
        $fingerprint = [regex]::Match($output,'SHA1:\s*([A-Fa-f0-9:]+)')
        if ($keyExit -ne 0 -or -not $fingerprint.Success) { throw 'Team keystore could not be verified.' }
        return $fingerprint.Groups[1].Value.ToUpperInvariant()
    } finally { [Environment]::SetEnvironmentVariable('TUI_KHON_KEYSTORE_PASSWORD',$oldPassword,'Process') }
}

function Assert-BundleDirectory([string]$Directory) {
    foreach ($name in $bundleFiles) {
        if (-not (Test-Path -LiteralPath (Join-Path $Directory $name) -PathType Leaf)) { throw "Bundle file missing: $name" }
    }
    $manifest = Get-Content -Raw -LiteralPath (Join-Path $Directory 'manifest.json') | ConvertFrom-Json
    if ($manifest.bundleVersion -ne 1 -or $manifest.packageName -ne $teamPackage) { throw 'Unsupported Team bundle version/package.' }
    foreach ($name in @('.env.team','signing.properties','team-debug.jks')) {
        $expected = $manifest.sha256.PSObject.Properties[$name].Value
        if (-not $expected -or (Get-FileHash -LiteralPath (Join-Path $Directory $name) -Algorithm SHA256).Hash -ne $expected) {
            throw "Bundle checksum mismatch: $name"
        }
    }
    Assert-ClientConfig (Read-Settings (Join-Path $Directory '.env.team'))
    if ((Get-SigningSha1 $Directory) -ne $manifest.signingSha1) { throw 'Bundle certificate does not match its manifest.' }
    return $manifest
}

function Assert-TeamInstalled {
    $envPath = Join-Path $repoRoot '.env.team'
    if (-not (Test-Path -LiteralPath $envPath) -or -not (Test-Path -LiteralPath (Join-Path $teamRoot 'manifest.json'))) {
        throw 'Team setup missing. Run: .\tool\team.ps1 setup -Bundle "C:\Downloads\TuiKhon-Team-Setup.zip"'
    }
    $manifest = Get-Content -Raw -LiteralPath (Join-Path $teamRoot 'manifest.json') | ConvertFrom-Json
    if ($manifest.bundleVersion -ne 1 -or $manifest.packageName -ne $teamPackage) { throw 'Unsupported installed Team bundle.' }
    foreach ($name in @('.env.team','signing.properties','team-debug.jks')) {
        $path = if ($name -eq '.env.team') { $envPath } else { Join-Path $teamRoot $name }
        if (-not (Test-Path -LiteralPath $path) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $manifest.sha256.PSObject.Properties[$name].Value) {
            throw "Installed Team file is missing/changed: $name. Existing files have not been overwritten."
        }
    }
    $config = Read-Settings $envPath
    Assert-ClientConfig $config
    if ((Get-SigningSha1 $teamRoot) -ne $manifest.signingSha1) { throw 'Installed Team signing certificate mismatch.' }
    Write-Host "Team app: $teamPackage | backend: $(([Uri]$config.SUPABASE_URL).Host)"
    Write-Host "Team certificate SHA-1: $($manifest.signingSha1)"
}

function Install-TeamBundle {
    if (-not $Bundle -or -not (Test-Path -LiteralPath $Bundle -PathType Leaf)) { throw 'Supply an existing private ZIP with -Bundle "C:\Downloads\TuiKhon-Team-Setup.zip".' }
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $staging = Join-Path ([IO.Path]::GetTempPath()) ('tui-khon-team-' + [Guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($staging) | Out-Null
    try {
        $archive = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $Bundle).Path)
        try {
            if ($archive.Entries.Count -ne 4) { throw 'Team ZIP must contain exactly four root files.' }
            $seen = @{}
            foreach ($entry in $archive.Entries) {
                if ($entry.FullName -notin $bundleFiles -or $seen.ContainsKey($entry.FullName) -or $entry.Length -gt 1048576) { throw 'Invalid or unexpected ZIP entry; archive was not installed.' }
                $seen[$entry.FullName] = $true
                [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,(Join-Path $staging $entry.FullName))
            }
        } finally { $archive.Dispose() }
        $null = Assert-BundleDirectory $staging
        # Validate every destination before writing any file. Never replace a personal setup.
        foreach ($name in $bundleFiles) {
            $target = if ($name -eq '.env.team') { Join-Path $repoRoot $name } else { Join-Path $teamRoot $name }
            if ((Test-Path -LiteralPath $target) -and (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath (Join-Path $staging $name) -Algorithm SHA256).Hash) {
                throw "Existing $name differs. Back it up and resolve manually; no Team files were overwritten."
            }
        }
        [IO.Directory]::CreateDirectory($teamRoot) | Out-Null
        foreach ($name in $bundleFiles) {
            $target = if ($name -eq '.env.team') { Join-Path $repoRoot $name } else { Join-Path $teamRoot $name }
            if (-not (Test-Path -LiteralPath $target)) { [IO.File]::Copy((Join-Path $staging $name),$target) }
        }
    } finally {
        # Only the exact files in our unique staging directory; no recursive deletion.
        foreach ($name in $bundleFiles) { $path = Join-Path $staging $name; if ([IO.File]::Exists($path)) { [IO.File]::Delete($path) } }
        [IO.Directory]::Delete($staging)
    }
    Assert-TeamInstalled
    Invoke-Checked $script:flutter @('pub','get')
    Invoke-Checked $script:flutter @('gen-l10n')
    Write-Host 'Team setup complete. Start an Android device, then run: .\tool\team.ps1 run'
}

function New-TeamBundle {
    if (-not $OutputDirectory) { $OutputDirectory = Join-Path (Split-Path -Parent $repoRoot) 'TuiKhon-Team-Private' }
    $destination = [IO.Path]::GetFullPath($OutputDirectory)
    if ($destination.TrimEnd('\') -eq $repoRoot.TrimEnd('\') -or $destination.StartsWith($repoRoot.TrimEnd('\') + '\',[StringComparison]::OrdinalIgnoreCase)) {
        throw 'Keep the private bundle directory outside this Git checkout.'
    }
    [IO.Directory]::CreateDirectory($destination) | Out-Null
    $configSource = Read-Settings (Join-Path $repoRoot '.env')
    $client = @{}
    foreach ($name in @('SUPABASE_URL','SUPABASE_ANON_KEY','GOOGLE_WEB_CLIENT_ID')) { $client[$name] = $configSource[$name] }
    $client.GOOGLE_IOS_CLIENT_ID = ''
    Assert-ClientConfig $client
    $store = Join-Path $destination 'team-debug.jks'
    $properties = Join-Path $destination 'signing.properties'
    if ((Test-Path -LiteralPath $store) -xor (Test-Path -LiteralPath $properties)) { throw 'Incomplete existing Team signing material; recover its backup. Never rotate it silently.' }
    if (-not (Test-Path -LiteralPath $store)) {
        $bytes = New-Object byte[] 24
        $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
        try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
        $pass = [Convert]::ToBase64String($bytes)
        $oldPassword = [Environment]::GetEnvironmentVariable('TUI_KHON_KEYSTORE_PASSWORD','Process')
        try {
            $env:TUI_KHON_KEYSTORE_PASSWORD = $pass
            $oldErrorPreference = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            try { $keyOutput = (& $script:keytool -genkeypair -keystore $store -storetype JKS -alias tui-khon-team-dev '-storepass:env' TUI_KHON_KEYSTORE_PASSWORD '-keypass:env' TUI_KHON_KEYSTORE_PASSWORD -keyalg RSA -keysize 2048 -validity 3650 -dname 'CN=Tui Khon Team Dev,OU=PRM393 Group 5,O=Internal Development,C=VN' 2>&1 | Out-String); $keyExit = $LASTEXITCODE }
            finally { $ErrorActionPreference = $oldErrorPreference }
            if ($keyExit -ne 0) { throw 'Could not generate Team development certificate.' }
            Write-Utf8 $properties "keyAlias=tui-khon-team-dev`nstorePassword=$pass`nkeyPassword=$pass`n"
        } finally { [Environment]::SetEnvironmentVariable('TUI_KHON_KEYSTORE_PASSWORD',$oldPassword,'Process') }
    }
    $lines = foreach ($name in @('SUPABASE_URL','SUPABASE_ANON_KEY','GOOGLE_WEB_CLIENT_ID','GOOGLE_IOS_CLIENT_ID')) { "$name=$($client[$name])" }
    Write-Utf8 (Join-Path $destination '.env.team') (($lines -join "`n") + "`n")
    $hashes = [ordered]@{}
    foreach ($name in @('.env.team','signing.properties','team-debug.jks')) { $hashes[$name] = (Get-FileHash -LiteralPath (Join-Path $destination $name) -Algorithm SHA256).Hash }
    $manifest = [ordered]@{bundleVersion=1;packageName=$teamPackage;signingSha1=(Get-SigningSha1 $destination);sha256=$hashes}
    Write-Utf8 (Join-Path $destination 'manifest.json') ($manifest | ConvertTo-Json -Depth 5)
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zipPath = Join-Path $destination 'TuiKhon-Team-Setup.zip'
    $fileStream = [IO.File]::Open($zipPath,[IO.FileMode]::Create)
    $archive = [IO.Compression.ZipArchive]::new($fileStream,[IO.Compression.ZipArchiveMode]::Create)
    try { foreach ($name in $bundleFiles) { $null = [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,(Join-Path $destination $name),$name) } } finally { $archive.Dispose(); $fileStream.Dispose() }
    Write-Host "Private bundle: $zipPath"
    Write-Host "Register Android OAuth: package=$teamPackage SHA-1=$($manifest.signingSha1)"
    Write-Host 'Share this ZIP privately with teammates; never upload it to GitHub. Existing signing material was preserved.'
}

function Select-AndroidDevice {
    $deviceJson = (& $script:flutter devices --machine | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'Could not list devices; run flutter devices.' }
    $devices = @($deviceJson | ConvertFrom-Json | Where-Object { $_.targetPlatform -like 'android*' -and $_.isSupported -ne $false })
    if ($DeviceId) {
        if (-not ($devices | Where-Object { $_.id -eq $DeviceId })) { throw "Android device '$DeviceId' not available. Run flutter devices and authorize USB debugging." }
        return $DeviceId
    }
    if ($devices.Count -eq 0) { throw 'No Android device. Start an emulator in Android Studio Device Manager or connect/authorize your phone. No app/data was removed.' }
    if ($devices.Count -eq 1) { return $devices[0].id }
    for ($i=0; $i -lt $devices.Count; $i++) { Write-Host "[$i] $($devices[$i].name) ($($devices[$i].id))" }
    $selected = 0
    if (-not [int]::TryParse((Read-Host 'Select Android device number'),[ref]$selected) -or $selected -lt 0 -or $selected -ge $devices.Count) { throw 'Invalid device selection. Use -DeviceId to choose explicitly.' }
    return $devices[$selected].id
}

Push-Location $repoRoot
try {
    Find-Flutter
    Find-AndroidTools
    switch ($Action) {
        'pack' { New-TeamBundle }
        'setup' { Install-TeamBundle }
        'doctor' { Assert-TeamInstalled; Write-Host 'Team configuration and signing verified. Use flutter doctor -v for full toolchain details.' }
        'run' {
            Assert-TeamInstalled
            $selectedDevice = Select-AndroidDevice
            $env:TUI_KHON_TEAM = '1'
            Invoke-Checked $script:flutter @('run','--debug','-d',$selectedDevice,'--dart-define-from-file=.env.team')
        }
        'build' {
            Assert-TeamInstalled
            $env:TUI_KHON_TEAM = '1'
            Invoke-Checked $script:flutter @('build','apk','--debug','--dart-define-from-file=.env.team')
            $artifact = Join-Path $repoRoot 'build\team\tui-khon-team-debug.apk'
            [IO.Directory]::CreateDirectory((Split-Path -Parent $artifact)) | Out-Null
            Copy-Item -LiteralPath (Join-Path $repoRoot 'build\app\outputs\flutter-apk\app-debug.apk') -Destination $artifact
            Write-Host "Team APK: $artifact"
        }
    }
} catch {
    Write-Error $_.Exception.Message -ErrorAction Continue
    exit 1
} finally {
    [Environment]::SetEnvironmentVariable('TUI_KHON_TEAM',$previousTeamMode,'Process')
    Pop-Location
}
