param(
    [Parameter(Mandatory = $true)][string]$Compiler,
    [string]$ReleaseDirectory,
    [string]$OutputDirectory,
    [string]$SourceCommit
)
$ErrorActionPreference = 'Stop'
$orbitRoot = Split-Path -Parent $PSScriptRoot
if (-not $ReleaseDirectory) { $ReleaseDirectory = Join-Path $orbitRoot 'build/windows/x64/runner/Release' }
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $orbitRoot 'release-assets/windows-preview' }
$orbitRelease = (Resolve-Path -LiteralPath $ReleaseDirectory).Path
$orbitCompiler = (Get-Command $Compiler -ErrorAction Stop).Source
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$orbitOutput = (Resolve-Path -LiteralPath $OutputDirectory).Path
$orbitVersionLine = Get-Content -LiteralPath (Join-Path $orbitRoot 'pubspec.yaml') | Where-Object { $_ -match '^version:' } | Select-Object -First 1
if ($orbitVersionLine -notmatch '^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$') {
    throw 'Expected a major.minor.patch+build version in pubspec.yaml.'
}
$orbitVersion = "$($Matches[1]).$($Matches[2]).$($Matches[3])"
$orbitFileVersion = "$orbitVersion.$($Matches[4])"
$orbitRequired = @('orbit_note.exe','flutter_windows.dll','pdfium.dll','sqlite3.dll','data/app.so','data/icudtl.dat','data/flutter_assets/AssetManifest.bin','collaboration/OrbitNote-Server.exe','collaboration/Start Orbit Server.cmd','collaboration/README.md')
foreach ($orbitRelative in $orbitRequired) {
    if (-not (Test-Path -LiteralPath (Join-Path $orbitRelease $orbitRelative) -PathType Leaf)) { throw "Missing runtime file: $orbitRelative" }
}
$orbitInputs = @(Get-Item -LiteralPath (Join-Path $orbitRelease 'orbit_note.exe')) +
    @(Get-ChildItem -LiteralPath $orbitRelease -File -Filter '*.dll') +
    @(Get-ChildItem -LiteralPath (Join-Path $orbitRelease 'data') -Recurse -File) +
    @(Get-Item -LiteralPath (Join-Path $orbitRelease 'collaboration/OrbitNote-Server.exe'), (Join-Path $orbitRelease 'collaboration/Start Orbit Server.cmd'), (Join-Path $orbitRelease 'collaboration/README.md'))
foreach ($orbitInput in $orbitInputs) {
    if ($orbitInput.Name -match '(?i)(client_secret|owner-key|\.secret$|\.jks$|\.keystore$|\.local\.json$|key\.properties$)') {
        throw 'Private material must not enter a Windows package.'
    }
}
& $orbitCompiler "/DOrbitSource=$orbitRelease" "/DOrbitOutput=$orbitOutput" "/DOrbitRoot=$orbitRoot" "/DOrbitVersion=$orbitVersion" "/DOrbitFileVersion=$orbitFileVersion" (Join-Path $PSScriptRoot 'packaging/windows.iss')
if ($LASTEXITCODE -ne 0) { throw 'Windows setup compilation failed.' }
$orbitInstaller = Join-Path $orbitOutput 'OrbitNote-Windows-x64-Setup.exe'
if (-not (Test-Path -LiteralPath $orbitInstaller -PathType Leaf)) { throw 'Compiler did not produce the setup EXE.' }
$orbitManifest = @{
    version=$orbitVersionLine.Substring($orbitVersionLine.IndexOf(':') + 1).Trim()
    sourceCommit=$SourceCommit
    unsigned=$true
    installerSha256=(Get-FileHash -LiteralPath $orbitInstaller -Algorithm SHA256).Hash.ToLowerInvariant()
    files=@($orbitInputs | Sort-Object FullName | ForEach-Object {
        @{path=[IO.Path]::GetRelativePath($orbitRelease,$_.FullName).Replace('\','/');bytes=$_.Length;sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
    })
}
$orbitManifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $orbitOutput 'Windows-package.json') -Encoding utf8
"$($orbitManifest.installerSha256)  OrbitNote-Windows-x64-Setup.exe" | Set-Content -LiteralPath (Join-Path $orbitOutput 'SHA256SUMS-Windows.txt') -Encoding ascii
Write-Output 'Per-user setup EXE built with the complete runtime; no app was launched.'
