<#
.SYNOPSIS
    Centralized test runner with code coverage for repo-nav.
    
.DESCRIPTION
    Loads configuration from PesterConfig.json and executes Invoke-Pester.
    This script is the single source of truth for running tests with coverage.
#>

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$configFile = Join-Path $repoRoot "PesterConfig.json"

if (-not (Test-Path $configFile)) {
    Write-Error "Configuration file not found: $configFile"
    exit 1
}

try {
    Write-Host "Loading Pester configuration from PesterConfig.json..." -ForegroundColor Cyan
    
    # Import-PowerShellDataFile doesn't work for JSON, so we use ConvertFrom-Json
    $configJson = Get-Content $configFile | ConvertFrom-Json
    
    # Initialize Pester Configuration
    Import-Module Pester -ErrorAction Stop
    $config = [PesterConfiguration]::Default
    
    # Map JSON to PesterConfiguration object
    $config.Run.Path = $configJson.Run.Path
    $config.Run.Exit = $false # We handle exit manually to ensure coverage check runs
    
    # Add ExcludePath if it exists in Run config (for test discovery)
    if ($configJson.Run.PSObject.Properties.Name -contains 'ExcludePath') {
        $config.Run.ExcludePath = $configJson.Run.ExcludePath
        Write-Host "Excluding from test discovery: $($configJson.Run.ExcludePath -join ', ')" -ForegroundColor DarkGray
    }
    
    $config.Output.Verbosity = $configJson.Output.Verbosity
    $config.CodeCoverage.Enabled = $configJson.CodeCoverage.Enabled
    
    # Build CodeCoverage.Path dynamically, excluding non-testable files
    # This is the official workaround recommended by Pester maintainers
    # See: https://github.com/pester/Pester/issues/2032#issuecomment-1496690768
    $coveragePaths = $configJson.CodeCoverage.Path | ForEach-Object {
        $basePath = Join-Path $repoRoot $_
        Get-ChildItem -Path $basePath -Recurse -File -Filter "*.ps1" |
            Where-Object { 
                $_.Name -ne '_index.ps1' -and
                $_.DirectoryName -notlike '*\Interfaces' -and
                $_.DirectoryName -notlike '*\Resources*' -and
                $_.DirectoryName -notlike '*\Dev'
            } | Select-Object -ExpandProperty FullName
    }
    
    if ($coveragePaths.Count -gt 0) {
        $config.CodeCoverage.Path = $coveragePaths
        Write-Host "Code coverage will analyze $($coveragePaths.Count) files (excluding interfaces, _index.ps1, resources, dev tools)" -ForegroundColor DarkGray
        
        # Debug: Check if interfaces are in the list
        $interfaceFiles = $coveragePaths | Where-Object { $_ -like '*\Interfaces\*' }
        if ($interfaceFiles.Count -gt 0) {
            Write-Warning "WARNING: $($interfaceFiles.Count) interface files are still in the coverage list!"
            $interfaceFiles | Select-Object -First 3 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
        } else {
            Write-Host "  OK: Interfaces successfully excluded" -ForegroundColor Green
        }
    } else {
        Write-Warning "No files found for code coverage analysis"
    }
    
    $config.CodeCoverage.OutputFormat = $configJson.CodeCoverage.OutputFormat
    $config.CodeCoverage.OutputPath = $configJson.CodeCoverage.OutputPath
    
    # Ensure target is a number
    $targetValue = [double]$configJson.CodeCoverage.CoveragePercentTarget
    $config.CodeCoverage.CoveragePercentTarget = $targetValue
    
    Write-Host "Invoking Pester with target coverage: $targetValue%" -ForegroundColor Yellow
    
    $result = Invoke-Pester -Configuration $config
    
    Write-Host "Pester invocation finished. Status: $($result.Result)" -ForegroundColor Gray
    
    # 1. Check for test failures
    if ($result.FailedCount -gt 0) {
        Write-Host "TESTS FAILED: $($result.FailedCount) test(s) failed." -ForegroundColor Red
        exit 1
    }

    # 2. Check coverage (Parse Jacoco XML)
    $actual = 0
    $coverageFile = Join-Path $repoRoot $configJson.CodeCoverage.OutputPath
    
    if (Test-Path $coverageFile) {
        Write-Host "Parsing coverage report: $coverageFile" -ForegroundColor Gray
        [xml]$xml = Get-Content $coverageFile -Raw
        
        # In Jacoco, the global total is a counter at the report level
        $globalCounter = $xml.report.counter | Where-Object { $_.type -eq 'INSTRUCTION' }
        
        if ($null -ne $globalCounter) {
            $covered = [double]$globalCounter.covered
            $missed = [double]$globalCounter.missed
            $total = $covered + $missed
            
            if ($total -gt 0) {
                $actual = [math]::Round(($covered / $total) * 100, 2)
            }
        } else {
            Write-Warning "Could not find global INSTRUCTION counter in $coverageFile"
        }
    } else {
        Write-Warning "Coverage file not found at $coverageFile"
    }

    $isSuccess = $actual -ge $targetValue
    $statusColor = "Green"
    if (-not $isSuccess) { $statusColor = "Red" }
    
    Write-Host "Final Coverage Check: $actual% (Target: $targetValue%)" -ForegroundColor $statusColor
    
    if (-not $isSuccess) {
        Write-Host "CRITICAL: COVERAGE FAILURE! Actual ${actual}% is less than Target ${targetValue}%" -ForegroundColor Red
        Write-Host "Push blocked. Please add more tests to meet the $targetValue% requirement." -ForegroundColor Yellow
        exit 1
    }

    Write-Host "COVERAGE PASSED: $actual%" -ForegroundColor Green
    exit 0
} catch {
    Write-Host "CRITICAL ERROR: $_" -ForegroundColor Red
    exit 1
}
