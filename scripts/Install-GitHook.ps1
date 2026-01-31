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

# Get repo root - always go up from scripts folder
$scriptPath = $PSScriptRoot
if ($scriptPath -match "scripts$") {
    # Running from scripts/ folder
    $repoRoot = Split-Path $scriptPath -Parent
} elseif ($scriptPath -match "\.git\\hooks$") {
    # Running from .git/hooks (shouldn't happen with bash wrapper, but just in case)
    $repoRoot = Split-Path (Split-Path $scriptPath -Parent) -Parent
} else {
    # Fallback - assume we're somewhere in the repo
    $repoRoot = $scriptPath
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

#region 2. Pester Tests (New)
$pesterPath = Join-Path $repoRoot "tests\Pester"
$srcPath = Join-Path $repoRoot "src"

if (Test-Path $pesterPath) {
    Write-Host "  [2/2] Running Pester tests with coverage..." -ForegroundColor Yellow
    
    try {
        # Define coverage paths (all .ps1 files in src, excluding _index.ps1)
        # Note: Pester 5+ CodeCoverage syntax
        # Create a temporary script for Pester execution to avoid string interpolation hell
        $tempPesterScript = Join-Path $repoRoot "scripts\Temp-RunPester.ps1"
        
        $pesterScriptContent = @"
`$ErrorActionPreference = 'Stop'
try {
    Import-Module Pester -ErrorAction Stop
    
    `$config = [PesterConfiguration]::Default
    `$config.Run.Path = '$pesterPath'
    `$config.Run.Exit = `$true
    `$config.Output.Verbosity = 'Normal'
    `$config.CodeCoverage.Enabled = `$true
    `$config.CodeCoverage.Path = '$srcPath'
    `$config.CodeCoverage.OutputFormat = 'Jacoco'
    `$config.CodeCoverage.OutputPath = 'coverage.xml'
    `$config.CodeCoverage.CoveragePercentTarget = 80
    
    `$result = Invoke-Pester -Configuration `$config
    
    if (`$result.FailedCount -gt 0) {
        Write-Error "TESTS FAILED: `$(`$result.FailedCount) test(s) failed."
        exit 1
    }
    
    # Manual coverage check via XML report (more reliable)
    if (Test-Path 'coverage.xml') {
        [xml]`$xml = Get-Content 'coverage.xml'
        
        # Jacoco format parsing
        `$counters = `$xml.report.counter | Where-Object { `$_.type -eq 'INSTRUCTION' }
        if (`$counters) {
            `$covered = [double]`$counters.covered
            `$missed = [double]`$counters.missed
            `$total = `$covered + `$missed
            
            if (`$total -gt 0) {
                `$actual = [math]::Round((`$covered / `$total) * 100, 2)
                `$target = 80
                
                if (`$actual -lt `$target) {
                     Write-Error "COVERAGE FAILURE: Actual coverage is `$actual% which is less than target `$target%"
                     exit 1
                }
            }
        }
    } else {
        Write-Warning "Coverage report not found - skipping threshold check"
    }
} catch {
    Write-Error "CRITICAL ERROR IN PESTER RUNNER: `$_"
    exit 1
}
"@
        Set-Content -Path $tempPesterScript -Value $pesterScriptContent
        
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tempPesterScript
        
        if ($LASTEXITCODE -ne 0) {
            $totalErrors += 1
            Write-Host "      [FAIL] Pester tests failed" -ForegroundColor Red
        } else {
            Write-Host "      [OK] Pester tests passed" -ForegroundColor Green
        }
        
        # Cleanup
        if (Test-Path $tempPesterScript) { Remove-Item $tempPesterScript -Force }
    } catch {
        Write-Host "      [FAIL] Pester runner error: $_" -ForegroundColor Red
        $totalErrors++
    }
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
