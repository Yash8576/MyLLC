param(
    [string]$AdminUser,
    [string]$Database = "buzzcart-daeb6-database",
    [string]$Host = "127.0.0.1",
    [int]$Port = 5432,
    [string]$MigrationsDir = "database/migrations"
)

if (-not $AdminUser) {
    Write-Host "Provide -AdminUser when running this script." -ForegroundColor Red
    Write-Host "Example: .\scripts\firebase\migrate-to-cloudsql.ps1 -AdminUser postgres" -ForegroundColor Yellow
    exit 1
}

$psql = Get-Command psql -ErrorAction SilentlyContinue
if (-not $psql) {
    Write-Host "psql is not installed or not in PATH." -ForegroundColor Red
    Write-Host "Install PostgreSQL client tools and rerun." -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Path $MigrationsDir)) {
    Write-Host "Migrations directory not found: $MigrationsDir" -ForegroundColor Red
    exit 1
}

Write-Host "Applying migrations from $MigrationsDir to $Database on $Host:$Port" -ForegroundColor Cyan

$migrationFiles = Get-ChildItem -Path $MigrationsDir -Filter "*.sql" | Sort-Object Name
if ($migrationFiles.Count -eq 0) {
    Write-Host "No migration files found in $MigrationsDir" -ForegroundColor Yellow
    exit 0
}

foreach ($file in $migrationFiles) {
    Write-Host "Running migration: $($file.Name)" -ForegroundColor Green
    psql "host=$Host port=$Port dbname=$Database user=$AdminUser sslmode=disable" -v ON_ERROR_STOP=1 -f $file.FullName
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Migration failed at $($file.Name). Stopping." -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

Write-Host "Applying grants from scripts/firebase/setup_roles.sql" -ForegroundColor Cyan
psql "host=$Host port=$Port dbname=$Database user=$AdminUser sslmode=disable" -v ON_ERROR_STOP=1 -f "scripts/firebase/setup_roles.sql"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Role/grant step failed. Check setup_roles.sql placeholders." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "Migration and role setup completed." -ForegroundColor Green
