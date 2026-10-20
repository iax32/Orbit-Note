param(
    [string]$Dart = 'dart',
    [string]$Output = 'build/windows/x64/runner/Release/collaboration'
)
$ErrorActionPreference = 'Stop'
$orbitRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $orbitRoot
try {
    $orbitServerOutput = [System.IO.Path]::GetFullPath((Join-Path $orbitRoot $Output))
    New-Item -ItemType Directory -Path $orbitServerOutput -Force | Out-Null
    $orbitStagedExe = Join-Path $orbitServerOutput 'OrbitNote-Server.next.exe'
    $orbitServerExe = Join-Path $orbitServerOutput 'OrbitNote-Server.exe'
    & $Dart compile exe --packages=.dart_tool/package_config.json tool/collaboration_server.dart -o $orbitStagedExe
    if ($LASTEXITCODE -ne 0) { throw 'Server compilation failed; the existing server executable was preserved.' }
    Move-Item -LiteralPath $orbitStagedExe -Destination $orbitServerExe -Force
    Copy-Item -LiteralPath 'tool/server/Start Orbit Server.cmd' -Destination $orbitServerOutput -Force
    Copy-Item -LiteralPath 'tool/server/README.md' -Destination $orbitServerOutput -Force
    Write-Output 'Standalone server built. No server process was started and no keys were packaged.'
} finally { Pop-Location }
