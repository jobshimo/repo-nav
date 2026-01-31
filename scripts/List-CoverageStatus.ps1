<#
.SYNOPSIS
    List all files with their current code coverage percentage to plan systematic improvement.
    
.DESCRIPTION
    This script helps you see which files need coverage improvement. It runs the full 
    test suite and shows coverage for each file, sorted by priority.
    
    Use this to decide which file to work on next with Test-FileCoverage.ps1.
    
.PARAMETER Threshold
    Only show files below this coverage threshold. Default: 80%
    
.PARAMETER SortBy
    How to sort files. Options: 'coverage', 'priority', 'name'. Default: 'priority'
    
.EXAMPLE
    .\scripts\List-CoverageStatus.ps1
    
.EXAMPLE
    .\scripts\List-CoverageStatus.ps1 -Threshold 50 -SortBy coverage
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [int]$Threshold = 80,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('coverage', 'priority', 'name')]
    [string]$SortBy = 'priority'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$coveragePath = Join-Path $repoRoot "coverage.xml"

# ============================================================================
# RUN FULL COVERAGE
# ============================================================================

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  COVERAGE STATUS FOR ALL FILES" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Running full test suite with coverage..." -ForegroundColor Gray
Write-Host ""

# Run all tests with coverage
& "$repoRoot\scripts\Test-WithCoverage.ps1" -NoCoverageReport | Out-Null

if (-not (Test-Path $coveragePath)) {
    Write-Host "ERROR: Coverage report not generated" -ForegroundColor Red
    exit 1
}

# ============================================================================
# PARSE COVERAGE XML
# ============================================================================

[xml]$coverage = Get-Content $coveragePath

$fileStats = @()

foreach ($package in $coverage.report.package) {
    foreach ($sourceFile in $package.sourcefile) {
        $fileName = $sourceFile.name
        
        # Skip test files and mocks
        if ($fileName -match "Tests\.ps1$" -or $fileName -match "Mock") {
            continue
        }
        
        # Parse counters
        $lineCounter = $sourceFile.counter | Where-Object { $_.type -eq "LINE" }
        if ($lineCounter) {
            $covered = [int]$lineCounter.covered
            $missed = [int]$lineCounter.missed
            $total = $covered + $missed
            
            if ($total -gt 0) {
                $percentage = [math]::Round(($covered / $total) * 100, 2)
                
                # Only include files below threshold
                if ($percentage -lt $Threshold) {
                    # Determine priority based on folder
                    $priority = if ($fileName -match "^src\\Services") { 1 }
                               elseif ($fileName -match "^src\\Core") { 2 }
                               elseif ($fileName -match "^src\\UI") { 3 }
                               else { 4 }
                    
                    $fileStats += [PSCustomObject]@{
                        File = $fileName
                        Coverage = $percentage
                        Covered = $covered
                        Total = $total
                        Priority = $priority
                        Status = if ($percentage -ge 80) { "[OK]" }
                                 elseif ($percentage -ge 60) { "[  ]" }
                                 else { "[!!]" }
                    }
                }
            }
        }
    }
}

# ============================================================================
# SORT AND DISPLAY
# ============================================================================

switch ($SortBy) {
    'coverage' { $fileStats = $fileStats | Sort-Object Coverage }
    'priority' { $fileStats = $fileStats | Sort-Object Priority, Coverage }
    'name' { $fileStats = $fileStats | Sort-Object File }
}

Write-Host ""
Write-Host "Files below $Threshold% coverage:" -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor DarkGray
Write-Host ""

if ($fileStats.Count -eq 0) {
    Write-Host " [OK] All files meet the $Threshold% threshold!" -ForegroundColor Green
    Write-Host ""
    exit 0
}

# Display table
foreach ($stat in $fileStats) {
    $color = if ($stat.Coverage -ge 60) { "Yellow" }
             elseif ($stat.Coverage -ge 40) { "DarkYellow" }
             else { "Red" }
    
    Write-Host " $($stat.Status) " -NoNewline
    Write-Host "$($stat.Coverage.ToString().PadLeft(5))%" -ForegroundColor $color -NoNewline
    Write-Host "  $($stat.Covered)/$($stat.Total)".PadRight(12) -NoNewline -ForegroundColor DarkGray
    Write-Host " $($stat.File)" -ForegroundColor White
}

Write-Host ""
Write-Host "Total files needing improvement: $($fileStats.Count)" -ForegroundColor Yellow
Write-Host ""
Write-Host "Legend:" -ForegroundColor Gray
Write-Host "  [!!] = <60% (Needs work)" -ForegroundColor Red
Write-Host "  [  ] = 60-79% (Almost there)" -ForegroundColor Yellow
Write-Host "  [OK] = 80%+ (Target met)" -ForegroundColor Green
Write-Host ""
Write-Host "Next step:" -ForegroundColor White
Write-Host "  .\scripts\Test-FileCoverage.ps1 -SourceFile 'src/Services/YourFile.ps1' -ShowUncovered" -ForegroundColor Gray
Write-Host ""
