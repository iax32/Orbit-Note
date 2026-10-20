param(
    [string]$Flutter = 'flutter',
    [switch]$LocalOnly
)
$ErrorActionPreference = 'Stop'
$orbitRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $orbitRoot
$orbitPreviousMode = $env:ORBIT_GOOGLE_BUILD_MODE
try {
    $orbitFlutterCommand = (Get-Command $Flutter -ErrorAction Stop).Source
    $orbitDart = Join-Path (Split-Path -Parent $orbitFlutterCommand) 'cache/dart-sdk/bin/dart.exe'
    if (-not (Test-Path -LiteralPath $orbitDart)) {
        throw 'Pass the Flutter SDK flutter.bat path so its bundled Dart SDK can build the release tools.'
    }
    $orbitConfig = Join-Path $orbitRoot 'config/google-drive.local.json'
    $orbitDefines = '.local/google-build.windows.json'
    if (-not $LocalOnly -and (Test-Path -LiteralPath $orbitConfig)) {
        $env:ORBIT_GOOGLE_BUILD_MODE = 'google-account-preview'
        & $orbitDart --packages=.dart_tool/package_config.json tool/prepare_google_build.dart --platform=windows "--config=$orbitConfig" "--output=$orbitDefines"
        if ($LASTEXITCODE -ne 0) { throw 'Google app configuration validation failed. No local-only release was substituted.' }
        Write-Output 'Building Windows with the registered Google desktop client.'
        & $Flutter build windows --release --no-pub "--dart-define-from-file=$orbitDefines"
    } else {
        Write-Output 'Building Windows local-only; Google app registration is not included.'
        & $Flutter build windows --release --no-pub
    }
    if ($LASTEXITCODE -ne 0) { throw 'Windows release build failed.' }
    & (Join-Path $PSScriptRoot 'build_server.ps1') -Dart $orbitDart
} finally {
    $env:ORBIT_GOOGLE_BUILD_MODE = $orbitPreviousMode
    Pop-Location
}
