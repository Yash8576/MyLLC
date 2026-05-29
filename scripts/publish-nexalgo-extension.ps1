param(
  [string]$ZipPath = "projects\nexalgo\extension\dist\nexalgo-extension.zip",
  [string]$EnvFile = "projects\nexalgo\extension\.env.webstore.local",
  [string]$PublisherId = $env:CHROME_WEBSTORE_PUBLISHER_ID,
  [string]$ExtensionId = $env:CHROME_WEBSTORE_EXTENSION_ID,
  [string]$ClientId = $env:CHROME_WEBSTORE_CLIENT_ID,
  [string]$ClientSecret = $env:CHROME_WEBSTORE_CLIENT_SECRET,
  [string]$RefreshToken = $env:CHROME_WEBSTORE_REFRESH_TOKEN,
  [switch]$Publish
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$resolvedZipPath = Join-Path $repoRoot $ZipPath
$resolvedEnvPath = Join-Path $repoRoot $EnvFile

if (Test-Path -LiteralPath $resolvedEnvPath) {
  Get-Content -LiteralPath $resolvedEnvPath | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith("#") -or -not $line.Contains("=")) {
      return
    }

    $parts = $line.Split("=", 2)
    $name = $parts[0].Trim()
    $value = $parts[1].Trim().Trim('"').Trim("'")

    if ($name) {
      Set-Item -Path "Env:$name" -Value $value
    }
  }

  $PublisherId = if ($PublisherId) { $PublisherId } else { $env:CHROME_WEBSTORE_PUBLISHER_ID }
  $ExtensionId = if ($ExtensionId) { $ExtensionId } else { $env:CHROME_WEBSTORE_EXTENSION_ID }
  $ClientId = if ($ClientId) { $ClientId } else { $env:CHROME_WEBSTORE_CLIENT_ID }
  $ClientSecret = if ($ClientSecret) { $ClientSecret } else { $env:CHROME_WEBSTORE_CLIENT_SECRET }
  $RefreshToken = if ($RefreshToken) { $RefreshToken } else { $env:CHROME_WEBSTORE_REFRESH_TOKEN }
}

foreach ($item in @(
  @{ Name = "PublisherId"; Value = $PublisherId },
  @{ Name = "ExtensionId"; Value = $ExtensionId },
  @{ Name = "ClientId"; Value = $ClientId },
  @{ Name = "ClientSecret"; Value = $ClientSecret },
  @{ Name = "RefreshToken"; Value = $RefreshToken }
)) {
  if ([string]::IsNullOrWhiteSpace($item.Value)) {
    throw "$($item.Name) is required. Add it to $resolvedEnvPath, pass it as a parameter, or set the matching CHROME_WEBSTORE_* environment variable."
  }
}

if (-not (Test-Path -LiteralPath $resolvedZipPath)) {
  throw "Extension zip not found: $resolvedZipPath"
}

$tokenResponse = Invoke-RestMethod `
  -Method Post `
  -Uri "https://oauth2.googleapis.com/token" `
  -Body @{
    client_id = $ClientId
    client_secret = $ClientSecret
    refresh_token = $RefreshToken
    grant_type = "refresh_token"
  }

$accessToken = $tokenResponse.access_token
$headers = @{
  Authorization = "Bearer $accessToken"
}

$uploadUrl = "https://chromewebstore.googleapis.com/upload/v2/publishers/$PublisherId/items/$($ExtensionId):upload"
$uploadResponse = Invoke-RestMethod `
  -Method Post `
  -Uri $uploadUrl `
  -Headers $headers `
  -ContentType "application/zip" `
  -InFile $resolvedZipPath

Write-Host "Upload response:"
$uploadResponse | ConvertTo-Json -Depth 8

if ($Publish) {
  $publishUrl = "https://chromewebstore.googleapis.com/v2/publishers/$PublisherId/items/$($ExtensionId):publish"
  $publishResponse = Invoke-RestMethod `
    -Method Post `
    -Uri $publishUrl `
    -Headers $headers

  Write-Host "Publish response:"
  $publishResponse | ConvertTo-Json -Depth 8
} else {
  Write-Host "Uploaded only. Re-run with -Publish when the store listing and privacy fields are ready."
}
