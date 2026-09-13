param(
    [Parameter(Mandatory = $true)][string]$DesktopCredentials,
    [string]$AndroidServerClientId = ''
)
$ErrorActionPreference = 'Stop'
$orbitRoot = Split-Path -Parent $PSScriptRoot
$orbitDestination = Join-Path $orbitRoot 'config/google-drive.local.json'
$orbitDownloaded = Get-Content -LiteralPath $DesktopCredentials -Raw | ConvertFrom-Json
if (-not $orbitDownloaded.installed) {
    throw 'Select the JSON downloaded for an OAuth Desktop app client, not a Web client.'
}
$orbitDesktop = $orbitDownloaded.installed
if ($orbitDesktop.client_id -notmatch '^[0-9]+-.+\.apps\.googleusercontent\.com$') {
    throw 'The Desktop OAuth client ID is missing or invalid.'
}
if ($AndroidServerClientId -and $AndroidServerClientId -notmatch '^[0-9]+-.+\.apps\.googleusercontent\.com$') {
    throw 'The Android SDK server client ID must be the public Web OAuth client ID from the same project.'
}
$orbitConfig = if (Test-Path -LiteralPath $orbitDestination) {
    Get-Content -LiteralPath $orbitDestination -Raw | ConvertFrom-Json -AsHashtable
} else { @{} }
$orbitConfig['ORBIT_GOOGLE_DESKTOP_CLIENT_ID'] = $orbitDesktop.client_id
$orbitConfig['ORBIT_GOOGLE_DESKTOP_CLIENT_SECRET'] = $orbitDesktop.client_secret ?? ''
if ($AndroidServerClientId) {
    $orbitConfig['ORBIT_GOOGLE_ANDROID_SERVER_CLIENT_ID'] = $AndroidServerClientId
}
# Configuration stays in the repository's ignored local configuration file.
# Never print credential values or copy a confidential Web client secret.
$orbitConfig | ConvertTo-Json | Set-Content -LiteralPath $orbitDestination -Encoding utf8
Write-Output 'Google build configuration saved locally. No account or Vault files were changed.'
Write-Output 'Build with: flutter build windows --release --dart-define-from-file=config/google-drive.local.json'
