[CmdletBinding()]
param(
    [string]$ProjectId = "buzzcart-daeb6",
    [string]$Region = "us-east4",
    [string]$ServiceName = "buzzcart-backend",
    [string]$CloudSqlInstance = "buzzcart-daeb6:us-east4:buzzcart-daeb6-instance",
    [string]$EnvFile = "..\\cloudrun.env.example"
)

$ErrorActionPreference = "Stop"

function Resolve-RepoRelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    $scriptDir = Split-Path -Parent $PSCommandPath
    return [System.IO.Path]::GetFullPath((Join-Path $scriptDir $Path))
}

$backendDir = Resolve-Path (Join-Path (Split-Path -Parent $PSCommandPath) "..")
$resolvedEnvFile = Resolve-RepoRelativePath $EnvFile

if (-not (Test-Path $resolvedEnvFile)) {
    throw "Env file not found: $resolvedEnvFile"
}

Write-Host "Deploying $ServiceName to Cloud Run in $ProjectId ($Region)..."
Write-Host "Backend path: $backendDir"
Write-Host "Env file: $resolvedEnvFile"

$deployArgs = @(
    "run",
    "deploy",
    $ServiceName,
    "--project", $ProjectId,
    "--region", $Region,
    "--source", $backendDir,
    "--allow-unauthenticated",
    "--add-cloudsql-instances", $CloudSqlInstance,
    "--env-vars-file", $resolvedEnvFile
)

& gcloud @deployArgs

if ($LASTEXITCODE -ne 0) {
    throw "gcloud run deploy failed with exit code $LASTEXITCODE"
}

Write-Host ""
Write-Host "Deployment complete. Verify the service health endpoint:"
Write-Host "  gcloud run services describe $ServiceName --project $ProjectId --region $Region --format='value(status.url)'"
