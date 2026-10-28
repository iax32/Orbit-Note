param(
    [string]$Flutter = 'flutter',
    [switch]$LocalOnly
)
$ErrorActionPreference = 'Stop'
$orbitRoot = Split-Path -Parent $PSScriptRoot
$orbitPreviousMode = $env:ORBIT_GOOGLE_BUILD_MODE
Push-Location -LiteralPath $orbitRoot
try {
    $orbitFlutterCommand = (Get-Command $Flutter -ErrorAction Stop).Source
    $orbitDart = Join-Path (Split-Path -Parent $orbitFlutterCommand) 'cache/dart-sdk/bin/dart.exe'
    if (-not (Test-Path -LiteralPath $orbitDart)) {
        throw 'Pass the Flutter SDK flutter.bat path.'
    }
    $orbitConfig = Join-Path $orbitRoot 'config/google-drive.local.json'
    $orbitDefines = '.local/google-build.android.json'
    $env:ORBIT_GOOGLE_BUILD_MODE = if ($LocalOnly) { 'local-only' } else { 'google-account-preview' }
    $orbitArguments = @('--platform=android', "--output=$orbitDefines")
    if (-not $LocalOnly -and (Test-Path -LiteralPath $orbitConfig)) {
        $orbitArguments += "--config=$orbitConfig"
    }
    & $orbitDart --packages=.dart_tool/package_config.json tool/prepare_google_build.dart @orbitArguments
    if ($LASTEXITCODE -ne 0) {
        throw 'Android Google registration is missing. Configure the Web client ID and matching Android package/signing certificate. A local-only release was not substituted.'
    }
    & $Flutter --no-version-check build apk --release --no-pub "--dart-define-from-file=$orbitDefines"
    if ($LASTEXITCODE -ne 0) { throw 'Android release build failed.' }
} finally {
    $env:ORBIT_GOOGLE_BUILD_MODE = $orbitPreviousMode
    Pop-Location
}
