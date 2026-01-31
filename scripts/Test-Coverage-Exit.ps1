Import-Module Pester -ErrorAction Stop

$repoRoot = Split-Path $PSScriptRoot -Parent
$runner = Join-Path $repoRoot "scripts\Test-WithCoverage.ps1"

Write-Host "Invoking Centralized Pester Runner..."
& powershell -ExecutionPolicy Bypass -File $runner

if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILURE DETECTED" -ForegroundColor Red
    exit 1
} else {
    Write-Host "SUCCESS DETECTED" -ForegroundColor Green
    exit 0
}
