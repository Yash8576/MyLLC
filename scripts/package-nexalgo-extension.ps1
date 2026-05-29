param(
  [Parameter(Mandatory = $true)]
  [string]$ApiBaseUrl,
  [string]$WebBaseUrl = "https://nexacoreglobal.org/projects/nexalgo",
  [string]$FirebaseApiKey = "AIzaSyChiOs7D_dHdXY4aadUfJyB-6f6XFXPPwo",
  [string]$OutputDir = "projects\nexalgo\extension\dist"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$sourceDir = Join-Path $repoRoot "projects\nexalgo\extension"
$buildDir = Join-Path $repoRoot $OutputDir
$packageDir = Join-Path $buildDir "nexalgo-extension"
$zipPath = Join-Path $buildDir "nexalgo-extension.zip"
$apiOrigin = ([Uri]$ApiBaseUrl).GetLeftPart([System.UriPartial]::Authority)

if (Test-Path -LiteralPath $packageDir) {
  Remove-Item -LiteralPath $packageDir -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $packageDir | Out-Null
Copy-Item -Path (Join-Path $sourceDir "manifest.json") -Destination $packageDir
Copy-Item -Path (Join-Path $sourceDir "src") -Destination (Join-Path $packageDir "src") -Recurse

$manifestPath = Join-Path $packageDir "manifest.json"
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$manifest.host_permissions = @(
  "https://leetcode.com/*",
  "https://www.geeksforgeeks.org/*",
  "https://identitytoolkit.googleapis.com/*",
  "https://securetoken.googleapis.com/*",
  "$apiOrigin/*"
)
$manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $manifestPath -Encoding ascii

$configPath = Join-Path $packageDir "src\config.js"
$config = @"
globalThis.NEXALGO_EXTENSION_CONFIG = {
  apiBaseUrl: '$($ApiBaseUrl.TrimEnd('/'))',
  webBaseUrl: '$($WebBaseUrl.TrimEnd('/'))',
  firebaseApiKey: '$FirebaseApiKey',
}
"@
Set-Content -LiteralPath $configPath -Value $config -Encoding ascii

if (Test-Path -LiteralPath $zipPath) {
  Remove-Item -LiteralPath $zipPath -Force
}

Compress-Archive -Path (Join-Path $packageDir "*") -DestinationPath $zipPath

Write-Host "Built unpacked extension: $packageDir"
Write-Host "Built Chrome Web Store zip: $zipPath"
