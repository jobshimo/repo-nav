<#
.SYNOPSIS
    Test runner for repo-nav unit tests.
    
.DESCRIPTION
    Runs all test files in the tests/ directory.
    
.EXAMPLE
    .\Run-Tests.ps1
    Runs all tests.
    
.EXAMPLE
    .\Run-Tests.ps1 -Filter "ArrayHelper"
    Runs only tests matching the filter.
#>

param(
    [string]$Filter = "*"
)

$testsPath = $PSScriptRoot
$totalPassed = 0
$totalFailed = 0
$testFiles = Get-ChildItem -Path $testsPath -Filter "Test-*.ps1"

if ($Filter -ne "*") {
    $testFiles = $testFiles | Where-Object { $_.Name -like "*$Filter*" }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  REPO-NAV TEST RUNNER" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

foreach ($testFile in $testFiles) {
    Write-Host "  Running: $($testFile.Name)..." -ForegroundColor Yellow
    Write-Host ""
    
    $exitCode = & $testFile.FullName
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  $($testFile.Name) - ALL PASSED" -ForegroundColor Green
    } else {
        Write-Host "  $($testFile.Name) - $LASTEXITCODE FAILED" -ForegroundColor Red
        $totalFailed += $LASTEXITCODE
    }
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor $(if ($totalFailed -eq 0) { "Green" } else { "Red" })

if ($totalFailed -eq 0) {
    Write-Host "  ALL TESTS PASSED!" -ForegroundColor Green
} else {
    Write-Host "  $totalFailed TEST(S) FAILED" -ForegroundColor Red
}

Write-Host "========================================" -ForegroundColor $(if ($totalFailed -eq 0) { "Green" } else { "Red" })
Write-Host ""

exit $totalFailed
