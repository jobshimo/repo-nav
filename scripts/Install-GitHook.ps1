<#
.SYNOPSIS
    Git pre-push hook for repo-nav
    
.DESCRIPTION
    Runs validation checks before allowing a push:
    1. Project structure validation
    2. Syntax checks
    3. Unit tests
    
    To install this hook:
    1. Run .\scripts\Install-PrePushHook.ps1
    2. Or manually copy to .git/hooks/pre-push
    
.NOTES
    Exit code 0 = push allowed
    Exit code 1 = push blocked
#>

$ErrorActionPreference = 'Stop'

# Get repo root (two levels up from .git/hooks)
$hookDir = $PSScriptRoot
if ($hookDir -match "\.git\\hooks$") {
    $repoRoot = Split-Path (Split-Path $hookDir -Parent) -Parent
} else {
    # Running directly (not from git hook)
    $repoRoot = $PSScriptRoot
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  PRE-PUSH VALIDATION" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$validationScript = Join-Path $repoRoot "scripts\Validate-Project.ps1"
$testRunner = Join-Path $repoRoot "tests\Run-Tests.ps1"

$totalErrors = 0

#region 1. Project Validation
if (Test-Path $validationScript) {
    Write-Host "  [1/2] Running project validation..." -ForegroundColor Yellow
    
    try {
        & $validationScript -SkipBuild
        
        if ($LASTEXITCODE -ne 0) {
            $totalErrors += $LASTEXITCODE
            Write-Host "      [FAIL] Validation failed" -ForegroundColor Red
        } else {
            Write-Host "      [OK] Validation passed" -ForegroundColor Green
        }
    } catch {
        Write-Host "      [FAIL] Validation script error: $_" -ForegroundColor Red
        $totalErrors++
    }
} else {
    Write-Host "  [1/2] Validation script not found - SKIPPED" -ForegroundColor Yellow
}
#endregion

#region 2. Unit Tests
if (Test-Path $testRunner) {
    Write-Host "  [2/2] Running unit tests..." -ForegroundColor Yellow
    
    try {
        & $testRunner
        
        if ($LASTEXITCODE -ne 0) {
            $totalErrors += $LASTEXITCODE
            Write-Host "      [FAIL] Tests failed" -ForegroundColor Red
        } else {
            Write-Host "      [OK] All tests passed" -ForegroundColor Green
        }
    } catch {
        Write-Host "      [FAIL] Test runner error: $_" -ForegroundColor Red
        $totalErrors++
    }
} else {
    Write-Host "  [2/2] Test runner not found - SKIPPED" -ForegroundColor Yellow
}
#endregion

Write-Host ""
Write-Host "========================================" -ForegroundColor $(if ($totalErrors -eq 0) { "Green" } else { "Red" })

if ($totalErrors -eq 0) {
    Write-Host "  OK: PUSH ALLOWED" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    exit 0
} else {
    Write-Host "  ERROR: PUSH BLOCKED - Fix errors first" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "  To bypass this check:" -ForegroundColor Yellow
    Write-Host "    git push --no-verify" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}
