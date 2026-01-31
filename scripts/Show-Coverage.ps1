<#
.SYNOPSIS
    Shows coverage percentage for each file from the last test run.
    
.DESCRIPTION
    Quick view of coverage status per file. Reads from existing coverage.xml.
    Run tests first with: .\scripts\Test-WithCoverage.ps1
    
.PARAMETER MinCoverage
    Only show files below this percentage. Default: 100 (shows all)
    
.EXAMPLE
    .\scripts\Show-Coverage.ps1
    Shows all files with their coverage
    
.EXAMPLE
    .\scripts\Show-Coverage.ps1 -MinCoverage 80
    Shows only files below 80%
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [int]$MinCoverage = 100
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$coveragePath = Join-Path $repoRoot "coverage.xml"

if (-not (Test-Path $coveragePath)) {
    Write-Host ""
    Write-Host "ERROR: No coverage report found" -ForegroundColor Red
    Write-Host "Run tests first: .\scripts\Test-WithCoverage.ps1" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "                 CODE COVERAGE BY FILE                          " -ForegroundColor Cyan -BackgroundColor DarkBlue
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

[xml]$coverage = Get-Content $coveragePath

$fileStats = @()

# Parse each source file - ensure packages is treated as array
$packages = @($coverage.report.package)
foreach ($package in $packages) {
    $sourceFiles = @($package.sourcefile)
    foreach ($sourceFile in $sourceFiles) {
        $fileName = $sourceFile.name
        
        # Skip test files and mocks
        if ($fileName -match "Tests\.ps1$" -or $fileName -match "Mock" -or $fileName -match "TestHelper") {
            continue
        }
        
        # Get LINE coverage (most relevant for PowerShell)
        $lineCounter = $sourceFile.counter | Where-Object { $_.type -eq "LINE" }
        if ($lineCounter) {
            $covered = [int]$lineCounter.covered
            $missed = [int]$lineCounter.missed
            $total = $covered + $missed
            
            if ($total -gt 0) {
                $percentage = [math]::Round(($covered / $total) * 100, 2)
                
                # Filter by threshold
                if ($percentage -lt $MinCoverage) {
                    $fileStats += [PSCustomObject]@{
                        File = $fileName
                        Coverage = $percentage
                        Covered = $covered
                        Missed = $missed
                        Total = $total
                    }
                }
            }
        }
    }
}

# Sort by coverage (lowest first)
$fileStats = $fileStats | Sort-Object Coverage, File

# Calculate totals
$totalCovered = ($fileStats | Measure-Object -Property Covered -Sum).Sum
$totalLines = ($fileStats | Measure-Object -Property Total -Sum).Sum
$globalCoverage = if ($totalLines -gt 0) { 
    [math]::Round(($totalCovered / $totalLines) * 100, 2) 
} else { 0 }

# Display results
if ($fileStats.Count -eq 0) {
    Write-Host "  [OK] " -ForegroundColor Green -NoNewline
    Write-Host "All files are at or above " -NoNewline
    Write-Host "$MinCoverage%" -ForegroundColor Green -NoNewline
    Write-Host " coverage!" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "Files below " -NoNewline -ForegroundColor Gray
    Write-Host "$MinCoverage%" -ForegroundColor Yellow -NoNewline
    Write-Host " coverage:" -ForegroundColor Gray
    Write-Host ""
    
    # Header
    Write-Host "  +----------+-------------+---------------------------------------+" -ForegroundColor DarkCyan
    Write-Host "  | " -ForegroundColor DarkCyan -NoNewline
    Write-Host "Coverage" -ForegroundColor White -NoNewline
    Write-Host " | " -ForegroundColor DarkCyan -NoNewline
    Write-Host "Lines      " -ForegroundColor White -NoNewline
    Write-Host " | " -ForegroundColor DarkCyan -NoNewline
    Write-Host "File                                 " -ForegroundColor White -NoNewline
    Write-Host " |" -ForegroundColor DarkCyan
    Write-Host "  +----------+-------------+---------------------------------------+" -ForegroundColor DarkCyan
    
    foreach ($stat in $fileStats) {
        # Color coding
        $color = if ($stat.Coverage -ge 80) { "Green" }
                 elseif ($stat.Coverage -ge 60) { "Yellow" }
                 elseif ($stat.Coverage -ge 40) { "DarkYellow" }
                 else { "Red" }
        
        # Status symbol
        $symbol = if ($stat.Coverage -ge 80) { "[OK]" }
                  elseif ($stat.Coverage -ge 60) { "[ -]" }
                  else { "[!!]" }
        
        $coverageStr = "$($stat.Coverage.ToString().PadLeft(5))%"
        $linesStr = "$($stat.Covered)/$($stat.Total)".PadRight(11)
        $fileStr = $stat.File
        if ($fileStr.Length -gt 37) { $fileStr = "..." + $fileStr.Substring($fileStr.Length - 34) }
        $fileStr = $fileStr.PadRight(37)
        
        Write-Host "  | " -ForegroundColor DarkCyan -NoNewline
        Write-Host $symbol -ForegroundColor $color -NoNewline
        Write-Host " " -NoNewline
        Write-Host $coverageStr -ForegroundColor $color -NoNewline
        Write-Host " | " -ForegroundColor DarkCyan -NoNewline
        Write-Host $linesStr -ForegroundColor Gray -NoNewline
        Write-Host " | " -ForegroundColor DarkCyan -NoNewline
        Write-Host $fileStr -ForegroundColor White -NoNewline
        Write-Host " |" -ForegroundColor DarkCyan
    }
    
    Write-Host "  +----------+-------------+---------------------------------------+" -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "  Total: " -NoNewline -ForegroundColor Gray
    Write-Host $fileStats.Count -ForegroundColor Yellow -NoNewline
    Write-Host " files below " -NoNewline -ForegroundColor Gray
    Write-Host "$MinCoverage%" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
$coverageColor = if ($globalCoverage -ge 80) { "Green" } else { "Yellow" }
Write-Host " Global Coverage: " -ForegroundColor White -NoNewline
Write-Host "$globalCoverage%" -ForegroundColor $coverageColor -BackgroundColor $(if ($globalCoverage -ge 80) { "DarkGreen" } else { "DarkYellow" })
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Legend:  " -ForegroundColor Gray -NoNewline
Write-Host "[OK]" -ForegroundColor Green -NoNewline
Write-Host " >= 80%   " -ForegroundColor Gray -NoNewline
Write-Host "[ - ]" -ForegroundColor Yellow -NoNewline
Write-Host " 60-79%   " -ForegroundColor Gray -NoNewline
Write-Host "[!!]" -ForegroundColor Red -NoNewline
Write-Host " < 60%" -ForegroundColor Gray
Write-Host ""
Write-Host "  Next: " -ForegroundColor Gray -NoNewline
Write-Host ".\scripts\Test-FileCoverage.ps1 -SourceFile 'path/to/file.ps1' -ShowUncovered" -ForegroundColor DarkGray
Write-Host ""

