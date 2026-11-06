# Windows PowerShell 5.1 / PowerShell 7. No server credentials are distributed.
[CmdletBinding()]
param(
    [ValidateSet('setup', 'doctor', 'run', 'build', 'pack')]
    [string]$Action = 'doctor',
    [string]$Bundle,
    [string]$DeviceId,
    [string]$OutputDirectory,
    [switch]$ReplaceEnv,
    [string]$Report
)

$ErrorActionPreference = 'Stop'
# Resolve caller-supplied paths before changing into the checkout.
if ($Bundle) { $Bundle = [IO.Path]::GetFullPath($Bundle) }
if ($OutputDirectory) { $OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory) }
$repoRoot = Split-Path -Parent $PSScriptRoot
$teamRoot = Join-Path $repoRoot '.team'
$teamPackage = 'com.example.tui_khon_mobile.team'
$utf8 = [System.Text.UTF8Encoding]::new($false)
$previousTeamMode = [Environment]::GetEnvironmentVariable('TUI_KHON_TEAM', 'Process')
$clientNames = @('SUPABASE_URL','SUPABASE_ANON_KEY','GOOGLE_WEB_CLIENT_ID','GOOGLE_IOS_CLIENT_ID')
$bundleFiles = @('.env', 'signing.properties', 'team-debug.jks', 'manifest.json')
$expectedTools = [ordered]@{flutter='3.47.7';dart='3.13.5';java='17'}
$diagnostic = [ordered]@{reportVersion=1;checkedAt=[DateTime]::UtcNow.ToString('o');action=$Action;status='checking';sourceCommit=(& git -C $repoRoot rev-parse HEAD 2>$null | Out-String).Trim();sourceDirty=$null;expectedTools=$expectedTools;actualTools=[ordered]@{};bundleVersion=$null;importedFromVersion=$null;packageName=$teamPackage;backendProject=$null;configSha256=$null;certificateSha1=$null;checks=[ordered]@{}}
$diagnostic.sourceDirty = [bool](& git -C $repoRoot status --porcelain --untracked-files=normal | Out-String).Trim()
if (-not $Report) { $Report = Join-Path $teamRoot 'diagnostics.json' }

function Save-Diagnostic {
    $target = [IO.Path]::GetFullPath($Report)
    # Keep all reports inside the ignored private directory, even when a custom name is supplied.
    if (-not $target.StartsWith($teamRoot.TrimEnd('\') + '\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Diagnostic report must be inside .team/.' }
    [IO.Directory]::CreateDirectory((Split-Path -Parent $target)) | Out-Null
    Write-Utf8 $target ($diagnostic | ConvertTo-Json -Depth 8)
    Write-Host "Sanitized diagnostic report: $target"
}

function Backup-PrivateFiles([string[]]$Paths) {
    $backup = Join-Path $teamRoot ('backups/' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfff') + '-' + [Guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($backup) | Out-Null
    foreach ($path in $Paths) {
        if (Test-Path -LiteralPath $path -PathType Leaf) { [IO.File]::Copy($path,(Join-Path $backup (Split-Path -Leaf $path))) }
    }
    Write-Host "Private originals backed up: $backup"
}

function Get-CanonicalEnv([hashtable]$Config) {
    return (($clientNames | ForEach-Object { "$_=$($Config[$_])" }) -join "`n") + "`n"
}

function Write-Manifest([string]$Directory, [int]$ImportedFrom = 2) {
    $hashes = [ordered]@{}
    foreach ($name in @('.env','signing.properties','team-debug.jks')) { $hashes[$name] = (Get-FileHash -LiteralPath (Join-Path $Directory $name) -Algorithm SHA256).Hash }
    $manifest = [ordered]@{bundleVersion=2;importedFromVersion=$ImportedFrom;packageName=$teamPackage;toolchain=$expectedTools;signingSha1=(Get-SigningSha1 $Directory);sha256=$hashes}
    Write-Utf8 (Join-Path $Directory 'manifest.json') ($manifest | ConvertTo-Json -Depth 6)
}


function Read-Settings([string]$Path) {
    $result = @{}
    foreach ($line in [IO.File]::ReadAllLines($Path)) {
        if ($line -match '^([A-Z_a-z][A-Z_a-z0-9.]*)\s*=(.*)$') {
            if ($result.ContainsKey($Matches[1])) { throw 'Duplicate configuration entry.' }
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
    if ($Config.Count -ne 4 -or @($allowed | Where-Object { -not $Config.ContainsKey($_) }).Count) { throw 'Team env must contain exactly the four application variables.' }
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
    $diagnostic.actualTools.flutter = $versionInfo.frameworkVersion
    $diagnostic.actualTools.dart = ($versionInfo.dartSdkVersion -split ' ')[0]
    $version = [version]($versionInfo.frameworkVersion -replace '-.*$', '')
    $dartVersion = [version](($versionInfo.dartSdkVersion -split ' ')[0] -replace '-.*$', '')
    if ($versionInfo.frameworkVersion -ne $expectedTools.flutter -or $diagnostic.actualTools.dart -ne $expectedTools.dart) {
        $diagnostic.checks.toolchain = 'failed'
        throw 'Team requires exactly Flutter 3.47.7 / Dart 3.13.5. Do not upgrade the lockfile to bypass this check.'
    }
    Write-Host "Flutter $($versionInfo.frameworkVersion) / Dart $($versionInfo.dartSdkVersion)"
}

function Find-AndroidTools {
    $doctor = (& $script:flutter doctor -v | Out-String) -replace '\x1B\[[0-?]*[ -/]*[@-~]', ''
    if ($doctor -match 'Android license status unknown|licenses not accepted|cmdline-tools component is missing|Unable to locate Android SDK') {
        throw 'Android SDK/licenses are incomplete. Run flutter doctor -v, install the listed SDK tools, and personally accept licenses with flutter doctor --android-licenses.'
    }
    $sdk = $null
    if ($doctor -match 'Android SDK at ([^\r\n]+)') { $sdk = $Matches[1].Trim() }
    foreach ($configuredSdk in @($env:ANDROID_HOME,$env:ANDROID_SDK_ROOT)) {
        if (-not $configuredSdk) { continue }
        if ($sdk -and [IO.Path]::GetFullPath($configuredSdk).TrimEnd('\') -ne [IO.Path]::GetFullPath($sdk).TrimEnd('\')) { throw 'Android SDK environment paths disagree with Flutter. Resolve the per-machine SDK configuration first.' }
        if (-not $sdk) { $sdk = $configuredSdk }
    }
    if (-not $sdk) { $sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
    if (-not (Test-Path -LiteralPath (Join-Path $sdk 'platform-tools\adb.exe'))) {
        throw 'Android SDK platform-tools not found. Configure the SDK in Android Studio and run flutter doctor -v.'
    }
    $script:adb = Join-Path $sdk 'platform-tools\adb.exe'
    $java = $null
    if ($doctor -match 'Java binary at: ([^\r\n]+)') { $java = $Matches[1].Trim() }
    if (-not $java) {
        # Some doctor failures return before printing Java; only trust Flutter's explicit override.
        $flutterConfig = (& $script:flutter config --list | Out-String)
        if ($flutterConfig -match '(?m)^\s*jdk-dir: ([^\r\n]+)') {
            $java = Join-Path $Matches[1].Trim() 'bin/java.exe'
        }
    }
    if (-not $java -or -not (Test-Path -LiteralPath $java)) { throw 'Cannot identify the JDK used by Flutter. Run flutter doctor -v.' }
    $oldErrorPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $javaText = (& $java -version 2>&1 | Out-String); $javaExit = $LASTEXITCODE } finally { $ErrorActionPreference = $oldErrorPreference }
    $javaMatch = [regex]::Match($javaText,'version "(\d+)[^"\r\n]*"')
    $diagnostic.actualTools.java = if ($javaMatch.Success) { $javaMatch.Groups[1].Value } else { 'unknown' }
    $diagnostic.actualTools.javaVersion = [regex]::Match($javaText,'version "([^"\r\n]+)"').Groups[1].Value
    if ($javaExit -ne 0 -or $diagnostic.actualTools.java -ne '17') { throw 'Flutter must use Java 17. Configure flutter config --jdk-dir <your JDK 17 directory>, then rerun doctor.' }
    $script:keytool = Join-Path (Split-Path -Parent $java) 'keytool.exe'
    if (-not (Test-Path -LiteralPath $script:keytool)) { throw 'JDK 17 keytool is missing.' }
    # Read the SDK/NDK contract from this exact Flutter installation, not a second hard-coded SDK list.
    $flutterRoot = Split-Path -Parent (Split-Path -Parent $script:flutter)
    $extension = Get-Content -Raw -LiteralPath (Join-Path $flutterRoot 'packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt')
    $compileSdk = [regex]::Match($extension,'val compileSdkVersion: Int = (\d+)').Groups[1].Value
    $ndk = [regex]::Match($extension,'val ndkVersion: String = "([^"]+)"').Groups[1].Value
    if (-not $compileSdk -or -not $ndk) { throw 'Cannot read the Flutter Android SDK contract.' }
    $diagnostic.actualTools.compileSdk = $compileSdk
    $diagnostic.actualTools.ndk = $ndk
    $wrapper = Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'android/gradle/wrapper/gradle-wrapper.properties')
    $diagnostic.actualTools.gradle = [regex]::Match($wrapper,'gradle-([0-9.]+)-').Groups[1].Value
    if (-not (Test-Path -LiteralPath (Join-Path $sdk "platforms/android-$compileSdk/android.jar")) -or -not (Test-Path -LiteralPath (Join-Path $sdk "ndk/$ndk/source.properties"))) { throw 'Android SDK platform/NDK required by Flutter is missing. Install the versions shown in the diagnostic report using Android Studio SDK Manager.' }
    if ((Read-Settings (Join-Path $sdk "ndk/$ndk/source.properties"))['Pkg.Revision'] -ne $ndk) { throw 'Installed NDK revision differs from the Flutter SDK contract.' }
    $localProperties = Join-Path $repoRoot 'android/local.properties'
    if (Test-Path -LiteralPath $localProperties) {
        $localSdk = (Read-Settings $localProperties)['sdk.dir']
        if ($localSdk) {
            $localSdk = $localSdk.Replace('\:',':').Replace('\\','\')
            if ([IO.Path]::GetFullPath($localSdk).TrimEnd('\') -ne [IO.Path]::GetFullPath($sdk).TrimEnd('\')) { throw 'android/local.properties uses a different SDK from Flutter. Resolve the per-machine SDK path before running.' }
        }
    }
    $diagnostic.checks.toolchain = 'passed'

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
    $manifest = Get-Content -Raw -LiteralPath (Join-Path $Directory 'manifest.json') | ConvertFrom-Json
    if ($manifest.bundleVersion -notin @(1,2) -or $manifest.packageName -ne $teamPackage) { throw 'Unsupported Team bundle version/package.' }
    $envName = if ($manifest.bundleVersion -eq 1) { '.env.team' } else { '.env' }
    foreach ($name in @($envName,'signing.properties','team-debug.jks')) {
        $path = Join-Path $Directory $name
        $expected = $manifest.sha256.PSObject.Properties[$name].Value
        if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or -not $expected -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $expected) { throw "Bundle checksum mismatch/missing file: $name" }
    }
    if ($manifest.bundleVersion -eq 2) {
        foreach ($name in $expectedTools.Keys) { if ($manifest.toolchain.$name -ne $expectedTools[$name]) { throw 'Bundle toolchain contract differs from source.' } }
    }
    Assert-ClientConfig (Read-Settings (Join-Path $Directory $envName))
    if ((Get-SigningSha1 $Directory) -ne $manifest.signingSha1) { throw 'Bundle certificate does not match its manifest.' }
    return $manifest
}

function Assert-TeamInstalled {
    $envPath = Join-Path $repoRoot '.env'
    $manifestPath = Join-Path $teamRoot 'manifest.json'
    if (-not (Test-Path -LiteralPath $envPath) -or -not (Test-Path -LiteralPath $manifestPath)) { throw 'Team setup missing. Run tool/team.ps1 setup -Bundle <private ZIP>.' }
    $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
    $diagnostic.bundleVersion = $manifest.bundleVersion
    $diagnostic.importedFromVersion = $manifest.importedFromVersion
    if ($manifest.bundleVersion -ne 2 -or $manifest.packageName -ne $teamPackage) { throw 'Old Team installation. Reimport the private ZIP with setup (old v1 ZIPs are supported).' }
    foreach ($name in $expectedTools.Keys) { if ($manifest.toolchain.$name -ne $expectedTools[$name]) { throw 'Installed bundle toolchain contract differs from source.' } }
    foreach ($name in @('.env','signing.properties','team-debug.jks')) {
        $path = if ($name -eq '.env') { $envPath } else { Join-Path $teamRoot $name }
        if (-not (Test-Path -LiteralPath $path)) { throw "Installed Team file is missing: $name" }
        $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        if ($name -eq '.env') { $diagnostic.configSha256 = $hash }
        if ($hash -ne $manifest.sha256.PSObject.Properties[$name].Value) { throw "Installed Team file changed: $name. Restore using setup -Bundle <ZIP> -ReplaceEnv; originals will be backed up. Signing files are never replaced." }
    }
    $config = Read-Settings $envPath
    Assert-ClientConfig $config
    $diagnostic.backendProject = ([Uri]$config.SUPABASE_URL).Host
    $diagnostic.certificateSha1 = Get-SigningSha1 $teamRoot
    if ($diagnostic.certificateSha1 -ne $manifest.signingSha1) { throw 'Installed Team signing certificate mismatch.' }
    $diagnostic.checks.configuration = 'passed'
    Write-Host "Team app: $teamPackage | backend: $($diagnostic.backendProject)"
    Write-Host "Configuration SHA-256: $($diagnostic.configSha256)"
    Write-Host "Team certificate SHA-1: $($diagnostic.certificateSha1)"
}

function Install-TeamBundle {
    if (-not $Bundle -or -not (Test-Path -LiteralPath $Bundle -PathType Leaf)) { throw 'Supply the private ZIP with -Bundle <path>.' }
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
                if ($entry.FullName -notin @('.env','.env.team','manifest.json','signing.properties','team-debug.jks') -or $seen.ContainsKey($entry.FullName) -or $entry.Length -gt 1048576) { throw 'Invalid ZIP entry; archive was not installed.' }
                $seen[$entry.FullName] = $true
                [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,(Join-Path $staging $entry.FullName))
            }
        } finally { $archive.Dispose() }
        $original = Assert-BundleDirectory $staging
        $oldEnvName = if ($original.bundleVersion -eq 1) { '.env.team' } else { '.env' }
        $oldEnvBytes = [IO.File]::ReadAllBytes((Join-Path $staging $oldEnvName))
        $canonical = Get-CanonicalEnv (Read-Settings (Join-Path $staging $oldEnvName))
        Write-Utf8 (Join-Path $staging '.env') $canonical
        Write-Manifest $staging $original.bundleVersion
        # Validate all destinations before touching any installed configuration.
        foreach ($name in @('signing.properties','team-debug.jks')) {
            $target = Join-Path $teamRoot $name
            if ((Test-Path -LiteralPath $target) -and (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath (Join-Path $staging $name) -Algorithm SHA256).Hash) { throw 'Existing Team signing material differs. No keys/configuration were replaced; recover the original bundle.' }
        }
        $envPath = Join-Path $repoRoot '.env'
        $different = (Test-Path -LiteralPath $envPath) -and (Get-FileHash -LiteralPath $envPath -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath (Join-Path $staging '.env') -Algorithm SHA256).Hash
        if ($different -and -not $ReplaceEnv) { throw 'Existing .env differs. Review the bundle, then explicitly rerun setup with -ReplaceEnv to back up and replace .env. No existing configuration was changed.' }
        [IO.Directory]::CreateDirectory($teamRoot) | Out-Null
        $legacyEnv = Join-Path $repoRoot '.env.team'
        $manifestPath = Join-Path $teamRoot 'manifest.json'
        $manifestDiffers = (Test-Path -LiteralPath $manifestPath) -and (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath (Join-Path $staging 'manifest.json') -Algorithm SHA256).Hash
        $backups = @()
        if ($different) { $backups += $envPath }
        if ($manifestDiffers) { $backups += $manifestPath }
        if (Test-Path -LiteralPath $legacyEnv) { $backups += $legacyEnv }
        if ($backups.Count) { Backup-PrivateFiles $backups }
        if ($original.bundleVersion -eq 1 -and ($manifestDiffers -or -not (Test-Path -LiteralPath $manifestPath))) {
            # Preserve the exact legacy env bytes, not just their normalized values.
            $legacyBackup = Join-Path $teamRoot ('backups/legacy-' + [Guid]::NewGuid().ToString('N'))
            [IO.Directory]::CreateDirectory($legacyBackup) | Out-Null
            [IO.File]::WriteAllBytes((Join-Path $legacyBackup '.env.team'),$oldEnvBytes)
        }
        foreach ($name in $bundleFiles) {
            $target = if ($name -eq '.env') { $envPath } else { Join-Path $teamRoot $name }
            if (-not (Test-Path -LiteralPath $target) -or (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath (Join-Path $staging $name) -Algorithm SHA256).Hash) { [IO.File]::Copy((Join-Path $staging $name),$target,$true) }
        }
        # Legacy root env is already backed up, and must not remain a second runnable config.
        if (Test-Path -LiteralPath $legacyEnv) { [IO.File]::Delete($legacyEnv) }
    } finally {
        foreach ($name in @('.env','.env.team','manifest.json','signing.properties','team-debug.jks')) { $path = Join-Path $staging $name; if ([IO.File]::Exists($path)) { [IO.File]::Delete($path) } }
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
    if ($destination.TrimEnd('\') -eq $repoRoot.TrimEnd('\') -or $destination.StartsWith($repoRoot.TrimEnd('\') + '\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Keep the private bundle directory outside this checkout.' }
    if (-not (Test-Path -LiteralPath (Join-Path $destination 'team-debug.jks')) -or -not (Test-Path -LiteralPath (Join-Path $destination 'signing.properties'))) { throw 'Existing Team signing material is required. This command never generates a new key.' }
    $source = Read-Settings (Join-Path $repoRoot '.env')
    $client = @{}
    foreach ($name in $clientNames) { $client[$name] = $source[$name] }
    Assert-ClientConfig $client
    # Back up existing bundle files together before changing the private bundle format.
    $backup = Join-Path $destination ('backups/' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfff') + '-' + [Guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($backup) | Out-Null
    foreach ($name in @('.env','.env.team','manifest.json','TuiKhon-Team-Setup.zip')) { $path = Join-Path $destination $name; if (Test-Path -LiteralPath $path) { [IO.File]::Copy($path,(Join-Path $backup $name)) } }
    $legacyPrivateEnv = Join-Path $destination '.env.team'
    if (Test-Path -LiteralPath $legacyPrivateEnv) { [IO.File]::Delete($legacyPrivateEnv) }
    Write-Utf8 (Join-Path $destination '.env') (Get-CanonicalEnv $client)
    Write-Manifest $destination
    $null = Assert-BundleDirectory $destination
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zipPath = Join-Path $destination 'TuiKhon-Team-Setup.zip'
    $fileStream = [IO.File]::Open($zipPath,[IO.FileMode]::Create)
    $archive = [IO.Compression.ZipArchive]::new($fileStream,[IO.Compression.ZipArchiveMode]::Create)
    try { foreach ($name in $bundleFiles) { $null = [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,(Join-Path $destination $name),$name) } } finally { $archive.Dispose(); $fileStream.Dispose() }
    $diagnostic.bundleVersion = 2
    $diagnostic.certificateSha1 = Get-SigningSha1 $destination
    $diagnostic.configSha256 = (Get-FileHash -LiteralPath (Join-Path $destination '.env') -Algorithm SHA256).Hash
    $diagnostic.backendProject = ([Uri]$client.SUPABASE_URL).Host
    Write-Host "Private bundle: $zipPath"
    Write-Host 'Existing Team key preserved. Share the ZIP only through a private channel.'
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
            Invoke-Checked $script:flutter @('run','--debug','-d',$selectedDevice,'--dart-define-from-file=.env')
        }
        'build' {
            Assert-TeamInstalled
            $env:TUI_KHON_TEAM = '1'
            Invoke-Checked $script:flutter @('build','apk','--debug','--dart-define-from-file=.env')
            $artifact = Join-Path $repoRoot 'build\team\tui-khon-team-debug.apk'
            [IO.Directory]::CreateDirectory((Split-Path -Parent $artifact)) | Out-Null
            Copy-Item -LiteralPath (Join-Path $repoRoot 'build\app\outputs\flutter-apk\app-debug.apk') -Destination $artifact
            Write-Host "Team APK: $artifact"
        }
    }
    $diagnostic.status = 'passed'
} catch {
    $diagnostic.status = 'failed'
    # Exception text is deliberately not written to the report: external tools may include credentials.
    Write-Error $_.Exception.Message -ErrorAction Continue
    exit 1
} finally {
    try { Save-Diagnostic } finally {
        [Environment]::SetEnvironmentVariable('TUI_KHON_TEAM',$previousTeamMode,'Process')
        Pop-Location
    }
}
