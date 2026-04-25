param(
    [string]$InstanceConnectionName = "buzzcart-daeb6:us-east4:buzzcart-daeb6-instance",
    [int]$Port = 5432
)

$proxy = Get-Command cloud-sql-proxy -ErrorAction SilentlyContinue
if (-not $proxy) {
    Write-Host "cloud-sql-proxy is not installed or not in PATH." -ForegroundColor Red
    Write-Host "Install it from Google Cloud SQL Auth Proxy docs, then rerun this script." -ForegroundColor Yellow
    exit 1
}

Write-Host "Starting Cloud SQL Auth Proxy on 127.0.0.1:$Port for $InstanceConnectionName" -ForegroundColor Cyan
Write-Host "Keep this terminal open while backend/chatbot connect." -ForegroundColor Yellow

cloud-sql-proxy --address 127.0.0.1 --port $Port $InstanceConnectionName
