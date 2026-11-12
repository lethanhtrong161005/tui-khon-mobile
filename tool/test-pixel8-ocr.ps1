param([string]$DeviceId = 'emulator-5554', [switch]$ProvidedReceipt)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repo
$avd = (& adb -s $DeviceId emu avd name 2>$null | Select-Object -First 1).Trim()
if ($LASTEXITCODE -ne 0 -or $avd -ne 'Pixel_8') { throw 'Start the existing Pixel_8 AVD and specify its device ID. This script never creates an AVD.' }
$previousTeam = $env:TUI_KHON_TEAM
try {
    $env:TUI_KHON_TEAM = '1'
    $arguments = @('build','apk','--debug','--target','integration_test/receipt_native_test.dart','--dart-define-from-file=.env','--dart-define=INTEGRATION_TEST_SHOULD_REPORT_RESULTS_TO_NATIVE=false')
    if ($ProvidedReceipt) { $arguments += '--dart-define=RECEIPT_QA_PROVIDED=true' }
    & flutter @arguments
    if ($LASTEXITCODE -ne 0) { throw 'QA build failed.' }
    # Install directly: Flutter's test launcher may uninstall after install errors.
    # This workflow only updates (-r), and stops if the installer rejects it.
    & adb -s $DeviceId install --no-streaming -r -t build/app/outputs/flutter-apk/app-debug.apk
    if ($LASTEXITCODE -ne 0) { throw 'Install rejected. Keep existing app/data; do not uninstall.' }
    & adb -s $DeviceId shell am force-stop com.example.tui_khon_mobile.team
    & adb -s $DeviceId shell am start -n com.example.tui_khon_mobile.team/com.example.tui_khon_mobile.MainActivity --ez enable-dart-profiling true --ez enable-checked-mode true --ez verify-entry-points true
    if ($LASTEXITCODE -ne 0) { throw 'Cannot start QA app.' }
    $serviceUri = $null
    for ($attempt=0; $attempt -lt 20; $attempt++) {
        Start-Sleep -Milliseconds 500
        $appProcessId = (& adb -s $DeviceId shell pidof com.example.tui_khon_mobile.team).Trim()
        if (-not $appProcessId) { continue }
        $lines = & adb -s $DeviceId logcat -d "--pid=$appProcessId" -s flutter
        $serviceMatches = [regex]::Matches(($lines -join "`n"), 'The Dart VM service is listening on (http://127\.0\.0\.1:(\d+)/\S+)')
        if ($serviceMatches.Count -gt 0) { $serviceUri = $serviceMatches[$serviceMatches.Count-1].Groups[1].Value; break }
    }
    if (-not $serviceUri) { throw 'QA VM service unavailable.' }
    $port = ([uri]$serviceUri).Port
    & adb -s $DeviceId forward "tcp:$port" "tcp:$port" | Out-Null
    # Attach only; this command cannot install/uninstall or replace the app.
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & flutter drive --driver=test_driver/integration_test.dart "--use-existing-app=$serviceUri" -d $DeviceId --no-dds --no-pub *> .dart_tool/receipt-native-pixel8-driver.log
    $driverExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorAction
    if ($driverExitCode -ne 0) { throw 'Native QA failed; inspect .dart_tool/receipt-native-pixel8-driver.log privately.' }
    Write-Host 'Native OCR and UI checks passed on existing Pixel_8.'
} finally {
    $env:TUI_KHON_TEAM = $previousTeam
}
