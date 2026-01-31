<#
.SYNOPSIS
    Build script to create a distribution package for repo-nav.

.DESCRIPTION
    This script creates a 'dist' folder containing:
    - repo-nav-bundle.ps1 (the bundled version)
    - Setup-Bundle.ps1 (installer for the bundle)
    
    FEATURES:
    - Auto-discovers imports from repo-nav.ps1 and _index.ps1 files
    - Pre-build validation (checks all files exist)
    - Single Source of Truth (no manual file list to maintain)
    
    Generated: $(Get-Date -Format "yyyy-MM-dd")

.EXAMPLE
    .\Build-Bundle.ps1
    Creates dist/ folder with bundled repo-nav and Setup.ps1
    
.EXAMPLE
    .\Build-Bundle.ps1 -Minify
    Creates minified bundle (no comments, smaller size)

.NOTES
    Run this script after any code changes to regenerate the distribution.
#>

param(
    [switch]$Minify
)

$ErrorActionPreference = 'Stop'
$scriptRoot = $PSScriptRoot
$srcPath = Join-Path $scriptRoot "src"
$distPath = Join-Path $scriptRoot "dist"
$mainScript = Join-Path $scriptRoot "repo-nav.ps1"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  REPO-NAV DISTRIBUTION BUILDER" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

#region Auto-Discovery Functions

function Get-ImportsFromFile {
    <#
    .SYNOPSIS
        Extracts all dot-sourced imports from a PowerShell file.
    #>
    param([string]$FilePath, [string]$BaseDir)
    
    $imports = @()
    $content = Get-Content $FilePath -ErrorAction SilentlyContinue
    $fileDir = Split-Path $FilePath -Parent
    
    # Pre-calculate common path variables (simulating what the script does)
    $parentDir = Split-Path $fileDir -Parent
    
    foreach ($line in $content) {
        # Match dot-source patterns: . "path" or . "$variable\path"
        if ($line -match '^\s*\.\s+"([^"]+)"') {
            $importPath = $matches[1]
            
            # Resolve variables in path
            $importPath = $importPath -replace '\$scriptRoot', $scriptRoot
            $importPath = $importPath -replace '\$srcPath', $srcPath
            $importPath = $importPath -replace '\$PSScriptRoot', $fileDir
            
            # Layer-specific path variables (same dir)
            $importPath = $importPath -replace '\$commandsPath', $fileDir
            $importPath = $importPath -replace '\$servicesPath', $fileDir
            $importPath = $importPath -replace '\$configPath', $fileDir
            $importPath = $importPath -replace '\$modelsPath', $fileDir
            $importPath = $importPath -replace '\$uiPath', $fileDir
            $importPath = $importPath -replace '\$enginePath', $fileDir
            $importPath = $importPath -replace '\$flowsPath', $fileDir
            $importPath = $importPath -replace '\$startupPath', $fileDir
            
            # Join-Path calculated variables (relative to parent)
            # $corePath = Join-Path (Split-Path $modelsPath -Parent) "Core"
            $importPath = $importPath -replace '\$corePath', (Join-Path $parentDir "Core")
            # $appPath = Join-Path (Split-Path $startupPath -Parent) "App"
            $importPath = $importPath -replace '\$appPath', (Join-Path $parentDir "App")
            
            # Normalize path
            $importPath = $importPath -replace '\\\\', '\'
            
            # Use absolute path for robust deduplication
            if (Test-Path $importPath) {
                $importPath = (Get-Item $importPath).FullName
            }
            
            $imports += $importPath
        }
    }
    
    return $imports
}

function Resolve-AllImports {
    <#
    .SYNOPSIS
        Recursively resolves all imports, following _index.ps1 files.
    #>
    param([string]$StartFile)
    
    $allFiles = [System.Collections.ArrayList]::new()
    $processed = @{}
    $queue = [System.Collections.Queue]::new()
    
    $queue.Enqueue($StartFile)
    
    while ($queue.Count -gt 0) {
        $currentFile = $queue.Dequeue()
        
        # Skip if already processed
        if ($processed.ContainsKey($currentFile)) { continue }
        $processed[$currentFile] = $true
        
        # Skip the main entry script (we don't bundle that, we parse it)
        if ($currentFile -eq $mainScript) {
            $imports = Get-ImportsFromFile -FilePath $currentFile -BaseDir $scriptRoot
            foreach ($imp in $imports) {
                if (-not $processed.ContainsKey($imp)) {
                    $queue.Enqueue($imp)
                }
            }
            continue
        }
        
        # Check if file exists
        if (-not (Test-Path $currentFile)) {
            Write-Host "        [WARN] Missing file: $currentFile" -ForegroundColor Yellow
            continue
        }
        
        # If it's an _index.ps1 file, don't add it but process its imports
        if ($currentFile -match '_index\.ps1$') {
            $imports = Get-ImportsFromFile -FilePath $currentFile -BaseDir (Split-Path $currentFile -Parent)
            foreach ($imp in $imports) {
                if (-not $processed.ContainsKey($imp)) {
                    $queue.Enqueue($imp)
                }
            }
        } else {
            # Regular .ps1 file - add to bundle list
            [void]$allFiles.Add($currentFile)
        }
    }
    
    return $allFiles
}

#endregion

#region Pre-Build Validation

Write-Host "  [1/5] Validating imports..." -ForegroundColor Yellow

$allFiles = Resolve-AllImports -StartFile $mainScript

$missingFiles = $allFiles | Where-Object { -not (Test-Path $_) }
if ($missingFiles.Count -gt 0) {
    Write-Host ""
    Write-Host "  BUILD FAILED - Missing files:" -ForegroundColor Red
    foreach ($f in $missingFiles) {
        Write-Host "    - $f" -ForegroundColor Red
    }
    Write-Host ""
    exit 1
}

Write-Host "        $($allFiles.Count) files discovered" -ForegroundColor DarkGray

#endregion

#region Create dist folder
Write-Host "  [2/5] Creating dist folder..." -ForegroundColor Yellow

if (Test-Path $distPath) {
    Remove-Item -Path $distPath -Recurse -Force
}
New-Item -Path $distPath -ItemType Directory -Force | Out-Null

Write-Host "        $distPath" -ForegroundColor DarkGray
#endregion

#region Build Bundle
Write-Host "  [3/5] Building repo-nav-bundle.ps1..." -ForegroundColor Yellow

$bundleContent = [System.Text.StringBuilder]::new()

# Header
$header = @"
<#
.SYNOPSIS
    repo-nav - Interactive Git Repository Navigator
    
.DESCRIPTION
    Navigate between repositories, manage aliases, install/remove node_modules,
    clone repositories from GitHub, and delete repositories with safety checks.
    
    This is a bundled distribution version. All source files are concatenated
    for faster startup (~2x speedup vs development version).
    
    Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    Files bundled: $($allFiles.Count)
    
.PARAMETER BasePath
    The base path where repositories are located.

.EXAMPLE
    .\repo-nav.ps1
    
.NOTES
    Author: Martin Miguel Bernal Garcia
    Run Setup.ps1 for initial configuration.
#>

param(
    [Parameter(Mandatory=`$false)]
    [string]`$BasePath
)

`$scriptRoot = `$PSScriptRoot

"@

[void]$bundleContent.AppendLine($header)

# Process each file
$processedCount = 0

foreach ($fullPath in $allFiles) {
    $relativePath = $fullPath.Replace($srcPath, "").TrimStart("\")
    
    $fileContent = Get-Content $fullPath -Raw -Encoding UTF8
    
    # ─────────────────────────────────────────────────────────────────────
    # BUILD TRANSFORMATIONS: Adapt development paths to bundle paths
    # ─────────────────────────────────────────────────────────────────────
    # Resources path: src\Resources\i18n → Resources\i18n
    $fileContent = $fileContent -replace 'src\\Resources\\i18n', 'Resources\i18n'
    $fileContent = $fileContent -replace 'src/Resources/i18n', 'Resources/i18n'
    
    if ($Minify) {
        # ─────────────────────────────────────────────────────────────────
        # AGGRESSIVE MINIFICATION
        # ─────────────────────────────────────────────────────────────────
        
        # Remove multi-line comment blocks <# ... #>
        $fileContent = $fileContent -replace '(?s)<#.*?#>', ''
        
        # Process line by line
        $lines = $fileContent -split "`n" | ForEach-Object {
            $line = $_
            
            # Remove trailing whitespace
            $line = $line.TrimEnd()
            
            # Skip empty lines
            if ([string]::IsNullOrWhiteSpace($line)) { return $null }
            
            # Skip single-line comments (but keep #region/#endregion for structure)
            $trimmed = $line.Trim()
            if ($trimmed -match '^#(?!region|endregion)' -and $trimmed -notmatch '^#>') {
                return $null
            }
            
            return $line
        } | Where-Object { $_ -ne $null }
        
        $fileContent = $lines -join "`n"
        
        # Don't add region markers in minified mode
        [void]$bundleContent.AppendLine($fileContent)
    }
    else {
        # Normal mode: keep regions for readability
        [void]$bundleContent.AppendLine("#region $relativePath")
        [void]$bundleContent.AppendLine($fileContent)
        [void]$bundleContent.AppendLine("#endregion")
        [void]$bundleContent.AppendLine("")
    }
    
    $processedCount++
}

# Footer
$footer = @"

#region Initialization
[Constants]::Initialize(`$scriptRoot)
#endregion

#region Main Entry Point
function Start-RepositoryNavigator {
    param([string]`$BasePath = (Split-Path -Parent `$PSScriptRoot))
    
    try {
        `$appContext = [AppBuilder]::Build(`$BasePath)
        Start-NavigationLoop -Context `$appContext
    }
    catch {
        Write-Host ""
        Write-Host "Error starting repository navigator:" -ForegroundColor Red
        Write-Host `$_.Exception.Message -ForegroundColor Red
        Write-Host ""
        Write-Host "Stack trace:" -ForegroundColor DarkGray
        Write-Host `$_.ScriptStackTrace -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "Press any key to exit..." -ForegroundColor Gray
        `$null = `$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}
#endregion

#region Execute
if (`$MyInvocation.InvocationName -ne '.') {
    if (-not `$BasePath) {
        `$BasePath = [Constants]::ReposBasePath
    }
    Start-RepositoryNavigator -BasePath `$BasePath
}
#endregion
"@

[void]$bundleContent.AppendLine($footer)

$bundlePath = Join-Path $distPath "repo-nav-bundle.ps1"
$bundleContent.ToString() | Set-Content -Path $bundlePath -Encoding UTF8 -Force

$bundleSize = [Math]::Round((Get-Item $bundlePath).Length / 1KB, 2)
Write-Host "        $processedCount files bundled ($bundleSize KB)" -ForegroundColor DarkGray
#endregion

#region Generate Setup-Bundle.ps1
Write-Host "  [4/5] Generating Setup-Bundle.ps1..." -ForegroundColor Yellow

# Copy the original Setup.ps1 and modify it for bundle
$originalSetup = Get-Content (Join-Path $scriptRoot "Setup.ps1") -Raw -Encoding UTF8

# Replace reference to repo-nav.ps1 with repo-nav-bundle.ps1
$distSetup = $originalSetup -replace 'repo-nav\.ps1', 'repo-nav-bundle.ps1'

# Change default command from 'listb' (dev) to 'list' (production)
$distSetup = $distSetup -replace '"listb"', '"list"'
$distSetup = $distSetup -replace 'listb" -NoNewline -ForegroundColor Green', 'list" -NoNewline -ForegroundColor Green'
$distSetup = $distSetup -replace '\(dev\), ', ''

# Remove pre-push hook installation (not needed in distributed version)
$distSetup = $distSetup -replace '(?s)# Install pre-push hook for development.*?\}\s*catch \{.*?\}', ''

$setupPath = Join-Path $distPath "Setup-Bundle.ps1"
$distSetup | Set-Content -Path $setupPath -Encoding UTF8 -Force

Write-Host "        Setup-Bundle.ps1 generated" -ForegroundColor DarkGray
#endregion

#region Copy Resources (translations)
Write-Host "  [5/5] Copying Resources (translations)..." -ForegroundColor Yellow

$resourcesSrc = Join-Path $srcPath "Resources"
$resourcesDst = Join-Path $distPath "Resources"

if (Test-Path $resourcesSrc) {
    Copy-Item -Path $resourcesSrc -Destination $resourcesDst -Recurse -Force
    $i18nFiles = (Get-ChildItem -Path $resourcesDst -Filter "*.json" -Recurse).Count
    Write-Host "        $i18nFiles translation files copied" -ForegroundColor DarkGray
} else {
    Write-Host "        [WARN] Resources folder not found" -ForegroundColor Yellow
}
#endregion

#region Generate Install.bat
$installBatContent = @"
@echo off
echo.
echo ============================================
echo   REPO-NAV INSTALLER
echo ============================================
echo.
echo This will configure PowerShell to run scripts
echo and then launch the Setup wizard.
echo.
pause

:: Enable script execution for the current user
powershell -Command "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force"

:: Run the Setup
powershell -ExecutionPolicy Bypass -File "%~dp0Setup-Bundle.ps1"

pause
"@

$installBatPath = Join-Path $distPath "Install.bat"
$installBatContent | Set-Content -Path $installBatPath -Encoding ASCII -Force
#endregion

#region Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  BUILD COMPLETE!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Distribution folder: $distPath" -ForegroundColor White
Write-Host ""
Write-Host "  Contents:" -ForegroundColor Cyan
Write-Host "    - Install.bat          (run this first)" -ForegroundColor Gray
Write-Host "    - repo-nav-bundle.ps1  ($bundleSize KB, $processedCount files)" -ForegroundColor Gray
Write-Host "    - Setup-Bundle.ps1" -ForegroundColor Gray
Write-Host "    - Resources/i18n/      (translations)" -ForegroundColor Gray
Write-Host ""
Write-Host "  To distribute:" -ForegroundColor Yellow
Write-Host "    1. Copy the 'dist' folder to target machine" -ForegroundColor Gray
Write-Host "    2. Double-click Install.bat (or run .\Setup-Bundle.ps1)" -ForegroundColor Gray
Write-Host ""
#endregion
