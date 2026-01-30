<#
.SYNOPSIS
    Project validation script for repo-nav.

.DESCRIPTION
    Validates project structure and catches common issues before commit:
    - All imported files exist
    - No orphan files (files not imported anywhere)
    - Syntax validation for all .ps1 files (ignoring type resolution)
    - Build-Bundle.ps1 succeeds

.EXAMPLE
    .\Validate-Project.ps1
    Runs all validations.
    
.EXAMPLE
    .\Validate-Project.ps1 -SkipBuild
    Runs validations without building.
#>

param(
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$scriptRoot = $PSScriptRoot
$repoRoot = Split-Path $scriptRoot -Parent
$srcPath = Join-Path $repoRoot "src"

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  REPO-NAV PROJECT VALIDATOR" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

$totalErrors = 0

#region 1. Syntax Validation
Write-Host "  [1/4] Syntax validation..." -ForegroundColor Yellow

$psFiles = Get-ChildItem -Path $srcPath -Filter "*.ps1" -Recurse
$syntaxIssues = 0
$filesWithRealErrors = @()

foreach ($file in $psFiles) {
    $syntaxErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile(
        $file.FullName, 
        [ref]$null, 
        [ref]$syntaxErrors
    )
    
    # Filter out "Unable to find type" errors - these are normal in static analysis
    # Only count REAL syntax errors (missing braces, invalid syntax, etc.)
    $realErrors = $syntaxErrors | Where-Object { 
        $_.Message -notmatch "Unable to find type" 
    }
    
    if ($realErrors.Count -gt 0) {
        $syntaxIssues++
        $filesWithRealErrors += $file.Name
        Write-Host "      [FAIL] $($file.Name)" -ForegroundColor Red
        foreach ($err in $realErrors) {
            Write-Host "        Line $($err.Extent.StartLineNumber): $($err.Message)" -ForegroundColor DarkRed
        }
    }
}

if ($syntaxIssues -eq 0) {
    Write-Host "      [OK] All $($psFiles.Count) files passed" -ForegroundColor Green
} else {
    Write-Host "      [FAIL] $syntaxIssues files with syntax errors" -ForegroundColor Red
    $totalErrors += $syntaxIssues
}
#endregion

#region 2. Import Chain Validation
Write-Host "  [2/4] Import chain validation..." -ForegroundColor Yellow

$mainScript = Join-Path $repoRoot "repo-nav.ps1"
$allImports = @{}

function Get-ImportsRecursive {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) { return }
    
    $content = Get-Content $FilePath -ErrorAction SilentlyContinue
    $fileDir = Split-Path $FilePath -Parent
    $parentDir = Split-Path $fileDir -Parent
    
    foreach ($line in $content) {
        if ($line -match '^\s*\.\s+"([^"]+)"') {
            $importPath = $matches[1]
            
            # Resolve variables - same logic as Build-Bundle.ps1
            $importPath = $importPath -replace '\$scriptRoot', $repoRoot
            $importPath = $importPath -replace '\$srcPath', $srcPath
            $importPath = $importPath -replace '\$PSScriptRoot', $fileDir
            
            # Layer-specific paths (same dir)
            $importPath = $importPath -replace '\$commandsPath', $fileDir
            $importPath = $importPath -replace '\$servicesPath', $fileDir
            $importPath = $importPath -replace '\$configPath', $fileDir
            $importPath = $importPath -replace '\$modelsPath', $fileDir
            $importPath = $importPath -replace '\$uiPath', $fileDir
            $importPath = $importPath -replace '\$enginePath', $fileDir
            $importPath = $importPath -replace '\$flowsPath', $fileDir
            $importPath = $importPath -replace '\$startupPath', $fileDir
            
            # Join-Path calculated variables (relative to parent)
            $importPath = $importPath -replace '\$corePath', (Join-Path $parentDir "Core")
            $importPath = $importPath -replace '\$appPath', (Join-Path $parentDir "App")
            
            # Normalize path
            $importPath = $importPath -replace '\\\\', '\'
            
            if (-not $allImports.ContainsKey($importPath)) {
                $allImports[$importPath] = $true
                
                if (Test-Path $importPath) {
                    if ($importPath -match '_index\.ps1$') {
                        Get-ImportsRecursive -FilePath $importPath
                    }
                }
            }
        }
    }
}

Get-ImportsRecursive -FilePath $mainScript

$missingImports = $allImports.Keys | Where-Object { -not (Test-Path $_) }
if ($missingImports.Count -gt 0) {
    Write-Host "      [FAIL] Missing imported files:" -ForegroundColor Red
    foreach ($f in $missingImports) {
        Write-Host "        - $f" -ForegroundColor DarkRed
    }
    $totalErrors += $missingImports.Count
} else {
    Write-Host "      [OK] All imported files exist ($($allImports.Count) files)" -ForegroundColor Green
}
#endregion

#region 3. Orphan Files Detection
Write-Host "  [3/4] Orphan files detection..." -ForegroundColor Yellow

$allSourceFiles = Get-ChildItem -Path $srcPath -Filter "*.ps1" -Recurse | 
    Where-Object { $_.Name -ne "_index.ps1" }

$orphanFiles = @()
foreach ($file in $allSourceFiles) {
    $isImported = $false
    foreach ($importPath in $allImports.Keys) {
        if ($importPath -eq $file.FullName -or $importPath -like "*$($file.Name)") {
            $isImported = $true
            break
        }
    }
    if (-not $isImported) {
        $orphanFiles += $file.FullName
    }
}

if ($orphanFiles.Count -gt 0) {
    Write-Host "      [WARN] Orphan files (not imported):" -ForegroundColor Yellow
    foreach ($f in $orphanFiles) {
        $relPath = $f.Replace($srcPath, "src")
        Write-Host "        - $relPath" -ForegroundColor DarkYellow
    }
    Write-Host "      (Not counted as errors - may be intentional)" -ForegroundColor DarkGray
} else {
    Write-Host "      [OK] No orphan files" -ForegroundColor Green
}
#endregion

#region 4. Build Validation
if (-not $SkipBuild) {
    Write-Host "  [4/4] Build validation..." -ForegroundColor Yellow
    
    $buildScript = Join-Path $repoRoot "Build-Bundle.ps1"
    $buildOutput = & powershell -ExecutionPolicy Bypass -File $buildScript 2>&1
    
    # Check for warnings in build output
    $warnings = $buildOutput | Select-String "\[WARN\]"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "      [FAIL] Build failed" -ForegroundColor Red
        $totalErrors++
    } elseif ($warnings) {
        Write-Host "      [WARN] Build succeeded with warnings:" -ForegroundColor Yellow
        foreach ($w in $warnings) {
            Write-Host "        $($w.Line)" -ForegroundColor DarkYellow
        }
    } else {
        $filesMatch = ($buildOutput | Select-String "files bundled").Line
        if ($filesMatch) {
            Write-Host "      [OK] $filesMatch" -ForegroundColor Green
        } else {
            Write-Host "      [OK] Build succeeded" -ForegroundColor Green
        }
    }
} else {
    Write-Host "  [4/4] Build validation... SKIPPED" -ForegroundColor DarkGray
}
#endregion

#region Summary
Write-Host ""
Write-Host "================================================" -ForegroundColor $(if ($totalErrors -eq 0) { "Green" } else { "Red" })

if ($totalErrors -eq 0) {
    Write-Host "  VALIDATION PASSED!" -ForegroundColor Green
} else {
    Write-Host "  VALIDATION FAILED - $totalErrors issue(s)" -ForegroundColor Red
}

Write-Host "================================================" -ForegroundColor $(if ($totalErrors -eq 0) { "Green" } else { "Red" })
Write-Host ""

exit $totalErrors
#endregion
