param(
  [string]$ProjectId = "nexalgo-ace83",
  [string]$Region = "us-east4",
  [string]$ServiceName = "nexalgo-backend",
  [string]$CloudSqlInstance = "",
  [string]$EnvFile = "projects\nexalgo\backend\cloudrun.env.yaml"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$backendDir = Join-Path $repoRoot "projects\nexalgo\backend"
$envPath = Join-Path $repoRoot $EnvFile

if (-not (Test-Path -LiteralPath $envPath)) {
  throw "Missing Cloud Run env file: $envPath. Create it from projects\nexalgo\backend\cloudrun.env.example."
}

$args = @(
  "run", "deploy", $ServiceName,
  "--project", $ProjectId,
  "--region", $Region,
  "--source", $backendDir,
  "--allow-unauthenticated",
  "--env-vars-file", $envPath
)

if ($CloudSqlInstance) {
  $args += @("--add-cloudsql-instances", $CloudSqlInstance)
}

& gcloud.cmd @args

$serviceUrl = & gcloud.cmd run services describe $ServiceName `
  --project $ProjectId `
  --region $Region `
  --format "value(status.url)"

Write-Host "NexAlgo backend deployed: $serviceUrl"
Write-Host "Set NEXT_PUBLIC_NEXALGO_API_BASE_URL=$serviceUrl/v1 in the nexacoreglobal.org frontend build environment."
