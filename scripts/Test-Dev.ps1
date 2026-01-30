<#
.SYNOPSIS
    Quick test script for repo-nav development.

.DESCRIPTION
    Tests the development version and optionally compares with bundle.

.EXAMPLE
    .\Test-Dev.ps1
    Tests development version only.
    
.EXAMPLE
    .\Test-Dev.ps1 -CompareBundle
    Tests both development and bundle versions.
#>

param(
    [switch]$CompareBundle
)

$scriptRoot = $PSScriptRoot
$repoRoot = Split-Path $scriptRoot -Parent
$devScript = Join-Path $repoRoot "repo-nav.ps1"
$bundleScript = Join-Path $repoRoot "dist\repo-nav-bundle.ps1"

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  REPO-NAV DEVELOPMENT TEST" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Check development version syntax
Write-Host "  [1] Checking syntax..." -ForegroundColor Yellow

$syntaxErrors = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile(
    $devScript, 
    [ref]$null, 
    [ref]$syntaxErrors
)

if ($syntaxErrors.Count -gt 0) {
    Write-Host "      [FAIL] Syntax errors in repo-nav.ps1:" -ForegroundColor Red
    foreach ($err in $syntaxErrors) {
        Write-Host "        Line $($err.Extent.StartLineNumber): $($err.Message)" -ForegroundColor Red
    }
    exit 1
} else {
    Write-Host "      [OK] No syntax errors" -ForegroundColor Green
}

# Run development version
Write-Host ""
Write-Host "  [2] Starting development version..." -ForegroundColor Yellow
Write-Host ""

& $devScript

if ($CompareBundle) {
    Write-Host ""
    Write-Host "  [3] Testing bundle version..." -ForegroundColor Yellow
    
    if (-not (Test-Path $bundleScript)) {
        Write-Host "      [WARN] Bundle not found. Run Build-Bundle.ps1 first." -ForegroundColor Yellow
    } else {
        Write-Host ""
        & $bundleScript
    }
}

Write-Host ""
Write-Host "  Test complete." -ForegroundColor Green
Write-Host ""
