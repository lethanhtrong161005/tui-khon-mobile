# Windows integration checks: isolated fixtures, fake Flutter, no cloud or app data.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Bundle)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root=Split-Path -Parent $PSScriptRoot
$work=Join-Path $root ('.dart_tool/team-script-tests-'+[Guid]::NewGuid().ToString('N'))
$utf8=[Text.UTF8Encoding]::new($false);$nl=[Environment]::NewLine;$passed=0
function Put([string]$Path,[string]$Text){[IO.Directory]::CreateDirectory((Split-Path -Parent $Path))|Out-Null;[IO.File]::WriteAllText($Path,$Text,$utf8)}
function Check([bool]$OK,[string]$Name){if(-not $OK){throw "FAIL: $Name"};Write-Host "PASS: $Name";$script:passed++}
$flutter=(Get-Command flutter).Source;$flutterRoot=Split-Path -Parent (Split-Path -Parent $flutter)
$config=(& $flutter config --list|Out-String);$doctor=(& $flutter doctor -v|Out-String)
$java=if($doctor -match 'Java binary at: ([^\r\n]+)'){$Matches[1].Trim()}elseif($config -match '(?m)^\s*jdk-dir: ([^\r\n]+)'){Join-Path $Matches[1].Trim() 'bin/java.exe'}else{throw 'Configure Java 17 in Flutter first.'}
$mock=Join-Path $work 'flutter/bin';$sdk=Join-Path $work 'android-sdk'
Put (Join-Path $sdk 'platform-tools/adb.exe') '';Put (Join-Path $sdk 'platforms/android-36/android.jar') ''
Put (Join-Path $sdk 'ndk/28.2.13676358/source.properties') 'Pkg.Revision = 28.2.13676358'
Put (Join-Path $work 'flutter/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt') (Get-Content -Raw (Join-Path $flutterRoot 'packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt'))
Put (Join-Path $mock 'version.json') '{"frameworkVersion":"3.47.7","dartSdkVersion":"3.13.5"}'
Put (Join-Path $mock 'doctor.txt') ((@("Android SDK at $sdk","Java binary at: $java")) -join $nl)
$batch=@('@echo off','if "%1"=="--version" (type "%~dp0version.json" & exit /b 0)','if "%1"=="doctor" (type "%~dp0doctor.txt" & exit /b 0)','if "%1"=="config" (exit /b 0)','if "%1"=="devices" (echo [{"id":"fixture-android","targetPlatform":"android-arm64","isSupported":true}] & exit /b 0)','echo %TUI_KHON_TEAM% %*>>"%~dp0calls.txt"','if "%1"=="build" (mkdir build\app\outputs\flutter-apk 2>nul & echo fixture>build\app\outputs\flutter-apk\app-debug.apk)','exit /b 0')
Put (Join-Path $mock 'flutter.cmd') ($batch -join $nl)
$material=Join-Path $work 'bundle';[IO.Directory]::CreateDirectory($material)|Out-Null
[IO.Compression.ZipFile]::ExtractToDirectory((Resolve-Path $Bundle).Path,$material)
$original=Get-Content -Raw (Join-Path $material 'manifest.json')|ConvertFrom-Json
# Public fake configuration replaces real client values before creating test bundles.
$fake=(@('SUPABASE_URL=https://team-fixture.supabase.co','SUPABASE_ANON_KEY=sb_publishable_fixture','GOOGLE_WEB_CLIENT_ID=123456-fixture.apps.googleusercontent.com','GOOGLE_IOS_CLIENT_ID=','') -join "`n")
function Make-Zip([int]$Version,[string]$Name){
 $envName=if($Version -eq 1){'.env.team'}else{'.env'};Put (Join-Path $material $envName) $fake
 $hashes=[ordered]@{};foreach($n in @($envName,'signing.properties','team-debug.jks')){$hashes[$n]=(Get-FileHash (Join-Path $material $n)).Hash}
 $m=[ordered]@{bundleVersion=$Version;packageName=$original.packageName;signingSha1=$original.signingSha1;toolchain=@{flutter='3.47.7';dart='3.13.5';java='17'};sha256=$hashes}
 Put (Join-Path $material 'manifest.json') ($m|ConvertTo-Json -Depth 6)
 $zip=Join-Path $work $Name;$stream=[IO.File]::Open($zip,[IO.FileMode]::Create);$archive=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create)
 try{foreach($n in @($envName,'signing.properties','team-debug.jks','manifest.json')){$null=[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,(Join-Path $material $n),$n)}}finally{$archive.Dispose();$stream.Dispose()};return $zip
}
$v2=Make-Zip 2 'v2.zip';$v1=Make-Zip 1 'v1.zip'
function Checkout([string]$Name){$path=Join-Path $work $Name;Put (Join-Path $path 'tool/team.ps1') (Get-Content -Raw (Join-Path $root 'tool/team.ps1'));Put (Join-Path $path 'android/gradle/wrapper/gradle-wrapper.properties') (Get-Content -Raw (Join-Path $root 'android/gradle/wrapper/gradle-wrapper.properties'));return $path}
function Run([string]$Checkout,[string[]]$Arguments){$pref=$ErrorActionPreference;$ErrorActionPreference='Continue';try{$output=(& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Checkout 'tool/team.ps1') @Arguments 2>&1|Out-String);$code=$LASTEXITCODE}finally{$ErrorActionPreference=$pref};Put (Join-Path $work 'last-command.log') $output;return $code}
$oldPath=$env:PATH;$oldHome=$env:ANDROID_HOME;$oldSdk=$env:ANDROID_SDK_ROOT
try{
 $env:PATH="$mock;$oldPath";$env:ANDROID_HOME=$sdk;$env:ANDROID_SDK_ROOT=$sdk;$a=Checkout 'new'
 Check ((Run $a @('setup','-Bundle',$v2)) -eq 0) 'v2 import'
 $envHash=(Get-FileHash (Join-Path $a '.env')).Hash;$certHash=(Get-FileHash (Join-Path $a '.team/team-debug.jks')).Hash
 Check ((Run $a @('setup','-Bundle',$v2)) -eq 0 -and -not (Test-Path (Join-Path $a '.team/backups'))) 'repeat setup has no backup churn'
 Check ((Run $a @('doctor')) -eq 0) 'installed doctor'
 $report=Get-Content -Raw (Join-Path $a '.team/diagnostics.json')|ConvertFrom-Json
 Check ($report.configSha256 -eq $envHash -and $report.certificateSha1 -eq $original.signingSha1 -and $report.backendProject -eq 'team-fixture.supabase.co') 'diagnostic fingerprints'
 Check ((Get-Content -Raw (Join-Path $a '.team/diagnostics.json')) -notmatch 'sb_publishable_fixture|storePassword|keyPassword') 'report excludes credentials'
 $changed=$fake+'OLD_UNUSED_SETTING=preserve-me'+$nl;Put (Join-Path $a '.env') $changed
 Check ((Run $a @('doctor')) -ne 0) 'changed env rejected'
 Check ((Run $a @('setup','-Bundle',$v2)) -ne 0 -and [IO.File]::ReadAllText((Join-Path $a '.env')) -eq $changed) 'implicit overwrite refused'
 Check ((Run $a @('setup','-Bundle',$v2,'-ReplaceEnv')) -eq 0) 'explicit replacement'
 $backed=@(Get-ChildItem (Join-Path $a '.team/backups') -Recurse -Force -File|Where-Object Name -eq '.env')
 Check ($backed.Count -eq 1 -and [IO.File]::ReadAllText($backed[0].FullName) -eq $changed) 'byte-for-byte original backup'
 $b=Checkout 'legacy';Put (Join-Path $b '.env.team') $fake
 Check ((Run $b @('setup','-Bundle',$v1)) -eq 0) 'v1 migration'
 Check ((Get-FileHash (Join-Path $b '.env')).Hash -eq $envHash -and (Get-FileHash (Join-Path $b '.team/team-debug.jks')).Hash -eq $certHash -and -not (Test-Path (Join-Path $b '.env.team'))) 'legacy normalized without changing key'
 Check (@(Get-ChildItem (Join-Path $b '.team/backups') -Recurse -Force -File|Where-Object Name -eq '.env.team').Count -ge 1) 'legacy env backup'
 Check ((Run $a @('run','-DeviceId','fixture-android')) -eq 0 -and (Run $a @('build')) -eq 0) 'run/build dispatch'
 $calls=@(Get-Content (Join-Path $mock 'calls.txt')|Where-Object {$_ -match ' (run|build) '})
 Check ($calls.Count -eq 2 -and @($calls|Where-Object {$_ -notmatch '^1 .*--dart-define-from-file=\.env$'}).Count -eq 0) 'Team profile and canonical env on both paths'
 Put (Join-Path $mock 'version.json') '{"frameworkVersion":"3.47.6","dartSdkVersion":"3.13.5"}'
 Check ((Run $a @('doctor')) -ne 0) 'wrong Flutter rejected'
 Put (Join-Path $mock 'version.json') '{"frameworkVersion":"3.47.7","dartSdkVersion":"3.13.4"}'
 Check ((Run $a @('doctor')) -ne 0) 'wrong Dart rejected'
 Put (Join-Path $mock 'version.json') '{"frameworkVersion":"3.47.7","dartSdkVersion":"3.13.5"}'
 Put (Join-Path $sdk 'ndk/28.2.13676358/source.properties') 'Pkg.Revision = 27.0.0'
 Check ((Run $a @('doctor')) -ne 0) 'wrong NDK rejected'
 Put (Join-Path $sdk 'ndk/28.2.13676358/source.properties') 'Pkg.Revision = 28.2.13676358'
 $unknownJava = Join-Path $work 'unknown-jdk/java.exe'
 [IO.Directory]::CreateDirectory((Split-Path -Parent $unknownJava))|Out-Null
 [IO.File]::Copy((Join-Path $env:SystemRoot 'System32/cmd.exe'),$unknownJava)
 Put (Join-Path $mock 'doctor.txt') ((@("Android SDK at $sdk","Java binary at: $unknownJava")) -join $nl)
 Check ((Run $a @('doctor')) -ne 0) 'unverified JDK rejected'
 Put (Join-Path $mock 'doctor.txt') ((@("Android SDK at $sdk","Java binary at: $java")) -join $nl)
 $corrupt=Join-Path $work 'corrupt.zip';[IO.File]::Copy($v2,$corrupt)
 $zip=[IO.Compression.ZipFile]::Open($corrupt,[IO.Compression.ZipArchiveMode]::Update)
 try{$zip.GetEntry('.env').Delete();$entry=$zip.CreateEntry('.env');$writer=[IO.StreamWriter]::new($entry.Open());try{$writer.Write($fake+'CHANGED=value')}finally{$writer.Dispose()}}finally{$zip.Dispose()}
 Check ((Run $a @('setup','-Bundle',$corrupt,'-ReplaceEnv')) -ne 0 -and (Get-FileHash (Join-Path $a '.env')).Hash -eq $envHash) 'corrupt ZIP rejected before writes'
 $unsafe=Join-Path $work 'unsafe.zip';[IO.File]::Copy($v2,$unsafe)
 $zip=[IO.Compression.ZipFile]::Open($unsafe,[IO.Compression.ZipArchiveMode]::Update)
 try{$zip.GetEntry('.env').Delete();$null=$zip.CreateEntry('../outside.env')}finally{$zip.Dispose()}
 Check ((Run $a @('setup','-Bundle',$unsafe)) -ne 0 -and -not (Test-Path (Join-Path $work 'outside.env'))) 'ZIP traversal rejected'
 Put (Join-Path $a '.team/signing.properties') 'keyAlias=unexpected'
 Check ((Run $a @('doctor')) -ne 0 -and (Run $a @('setup','-Bundle',$v2,'-ReplaceEnv')) -ne 0) 'changed signing rejected even with ReplaceEnv'
 Write-Host "$passed checks passed. Private fixtures: $work"
}finally{$env:PATH=$oldPath;$env:ANDROID_HOME=$oldHome;$env:ANDROID_SDK_ROOT=$oldSdk}
