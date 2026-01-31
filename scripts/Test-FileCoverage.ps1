<#
.SYNOPSIS
    Test code coverage for a SPECIFIC file to reach 80% goal incrementally.
    
.DESCRIPTION
    This script allows focused testing on ONE file at a time, preventing the 
    "jumping around" problem. Measures coverage for a single source file and
    its corresponding test file.
    
    Use this for incremental improvement: pick a file, bring it to 80%, then move to next.
    
.PARAMETER SourceFile
    Relative path to the source file to test (from repo root).
    Example: "src/Services/NpmService.ps1"
    
.PARAMETER TestFile
    Optional. Path to the test file. If not provided, attempts to find it automatically.
    Example: "tests/Pester/Unit/Services/NpmService.Tests.ps1"
    
.PARAMETER ShowUncovered
    If specified, shows which lines are NOT covered by tests.
    
.EXAMPLE
    .\scripts\Test-FileCoverage.ps1 -SourceFile "src/Services/NpmService.ps1"
    
.EXAMPLE
    .\scripts\Test-FileCoverage.ps1 -SourceFile "src/Core/RepositoryManager.ps1" -ShowUncovered
    
.EXAMPLE
    .\scripts\Test-FileCoverage.ps1 -SourceFile "src/Services/GitService.ps1" -TestFile "tests/Pester/Unit/Services/GitService.Tests.ps1"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$SourceFile,
    
    [Parameter(Mandatory=$false)]
    [string]$TestFile,
    
    [Parameter(Mandatory=$false)]
    [switch]$ShowUncovered
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Resolve-SourcePath {
    param([string]$Path)
    
    # Handle both relative and absolute paths
    if ([System.IO.Path]::IsPathRooted($Path)) {
        $fullPath = $Path
    } else {
        $fullPath = Join-Path $repoRoot $Path
    }
    
    if (-not (Test-Path $fullPath)) {
        throw "Source file not found: $fullPath"
    }
    
    return $fullPath
}

function Find-TestFile {
    param([string]$SourcePath)
    
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($SourcePath)
    $testFileName = "$fileName.Tests.ps1"
    
    # Search in common test locations
    $searchPaths = @(
        "tests\Pester\Unit",
        "tests\Pester\Unit\Services",
        "tests\Pester\Unit\Core",
        "tests\Pester\Unit\UI",
        "tests\Pester\Unit\Commands",
        "tests\Pester\Integration"
    )
    
    foreach ($searchPath in $searchPaths) {
        $testPath = Join-Path $repoRoot $searchPath
        $found = Get-ChildItem -Path $testPath -Filter $testFileName -Recurse -ErrorAction SilentlyContinue
        if ($found) {
            return $found.FullName
        }
    }
    
    Write-Warning "Test file not found for: $fileName"
    Write-Host "Searched in: tests\Pester\Unit and subfolders" -ForegroundColor DarkGray
    return $null
}

function Show-CoverageSummary {
    param(
        [object]$CoverageResult,
        [string]$SourceFile
    )
    
    $fileName = [System.IO.Path]::GetFileName($SourceFile)
    
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host " CODE COVERAGE REPORT: $fileName" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    $commandsCovered = $CoverageResult.CommandsExecutedCount
    $commandsTotal = $CoverageResult.CommandsAnalyzedCount
    $percentage = if ($commandsTotal -gt 0) { 
        [math]::Round(($commandsCovered / $commandsTotal) * 100, 2) 
    } else { 0 }
    
    # Color based on percentage
    $color = if ($percentage -ge 80) { "Green" }
             elseif ($percentage -ge 60) { "Yellow" }
             elseif ($percentage -ge 40) { "DarkYellow" }
             else { "Red" }
    
    Write-Host " Commands Covered:  " -NoNewline
    Write-Host "$commandsCovered / $commandsTotal" -ForegroundColor $color
    
    Write-Host " Coverage:          " -NoNewline
    Write-Host "$percentage%" -ForegroundColor $color -NoNewline
    
    if ($percentage -ge 80) {
        Write-Host " [OK] TARGET MET" -ForegroundColor Green
    } else {
        $gap = 80 - $percentage
        Write-Host " (need +$([math]::Round($gap, 2))% to reach 80%)" -ForegroundColor DarkYellow
    }
    
    Write-Host ""
    
    # Progress bar
    $barWidth = 50
    $filled = [math]::Floor(($percentage / 100) * $barWidth)
    $empty = $barWidth - $filled
    
    Write-Host " Progress: [" -NoNewline
    Write-Host ("#" * $filled) -NoNewline -ForegroundColor $color
    Write-Host ("." * $empty) -NoNewline -ForegroundColor DarkGray
    Write-Host "]" 
    
    Write-Host ""
}

function Show-UncoveredLines {
    param(
        [object]$CoverageResult,
        [string]$SourceFile
    )
    
    $missedCommands = $CoverageResult.CommandsMissed
    
    if ($missedCommands.Count -eq 0) {
        Write-Host "[OK] All lines are covered!" -ForegroundColor Green
        return
    }
    
    Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host " UNCOVERED LINES (need tests for these):" -ForegroundColor Yellow
    Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
    
    # Group by line number
    $lineGroups = $missedCommands | Group-Object -Property Line | Sort-Object Name
    
    foreach ($group in $lineGroups) {
        $lineNum = $group.Name
        $command = $group.Group[0].Command
        
        Write-Host " Line $($lineNum.PadLeft(4)): " -NoNewline -ForegroundColor DarkGray
        Write-Host $command -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "Total uncovered lines: $($lineGroups.Count)" -ForegroundColor Yellow
    Write-Host ""
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  FOCUSED FILE COVERAGE TEST" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Resolve source file path
$sourceFullPath = Resolve-SourcePath -Path $SourceFile
Write-Host "Source File: $sourceFullPath" -ForegroundColor Gray

# Find or use provided test file
if (-not $TestFile) {
    $testFullPath = Find-TestFile -SourcePath $sourceFullPath
    if (-not $testFullPath) {
        Write-Host ""
        Write-Host "ERROR: No test file found. Please create one or specify with -TestFile" -ForegroundColor Red
        Write-Host ""
        Write-Host "Suggested location:" -ForegroundColor Yellow
        $fileName = [System.IO.Path]::GetFileNameWithoutExtension($sourceFullPath)
        Write-Host "  tests\Pester\Unit\$fileName.Tests.ps1" -ForegroundColor White
        Write-Host ""
        exit 1
    }
} else {
    $testFullPath = Join-Path $repoRoot $TestFile
    if (-not (Test-Path $testFullPath)) {
        throw "Test file not found: $testFullPath"
    }
}

Write-Host "Test File:   $testFullPath" -ForegroundColor Gray
Write-Host ""

# Import Pester
Import-Module Pester -ErrorAction Stop

# Configure Pester for this specific file
$config = [PesterConfiguration]::Default
$config.Run.Path = $testFullPath
$config.Run.Exit = $false
$config.Run.PassThru = $true
$config.Output.Verbosity = 'Detailed'
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = $sourceFullPath
$config.CodeCoverage.OutputFormat = "JaCoCo"
$config.CodeCoverage.OutputPath = Join-Path $repoRoot "coverage-single.xml"

Write-Host "Running tests..." -ForegroundColor Cyan

# Run tests
$result = Invoke-Pester -Configuration $config

# Check test results
if ($result.FailedCount -gt 0) {
    Write-Host ""
    Write-Host "ERROR: Tests failed. Fix failing tests before checking coverage." -ForegroundColor Red
    exit 1
}

# Show coverage summary
Show-CoverageSummary -CoverageResult $result.CodeCoverage -SourceFile $sourceFullPath

# Show uncovered lines if requested
if ($ShowUncovered) {
    Show-UncoveredLines -CoverageResult $result.CodeCoverage -SourceFile $sourceFullPath
}

# Final status
Write-Host "================================================================" -ForegroundColor Cyan
$percentage = if ($result.CodeCoverage.CommandsAnalyzedCount -gt 0) {
    [math]::Round(($result.CodeCoverage.CommandsExecutedCount / $result.CodeCoverage.CommandsAnalyzedCount) * 100, 2)
} else { 0 }

if ($percentage -ge 80) {
    Write-Host " [OK] COVERAGE TARGET MET (80%)" -ForegroundColor Green
    exit 0
} else {
    Write-Host " [!] Coverage below target ($percentage% < 80%)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor White
    Write-Host "  1. Run with -ShowUncovered to see what needs tests" -ForegroundColor Gray
    Write-Host "  2. Add tests for uncovered lines" -ForegroundColor Gray
    Write-Host "  3. Run this script again to verify improvement" -ForegroundColor Gray
    Write-Host ""
    exit 0
}
