<#
.SYNOPSIS
    Build script to create a distribution package for repo-nav.

.DESCRIPTION
    This script creates a 'dist' folder containing:
    - repo-nav.ps1 (the bundled version)
    - Setup.ps1 (installer for the bundle)
    
    The dist folder can be copied to any machine for installation.

.EXAMPLE
    .\Build-Bundle.ps1
    Creates dist/ folder with bundled repo-nav and Setup.ps1

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

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  REPO-NAV DISTRIBUTION BUILDER" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

#region Create dist folder
Write-Host "  [1/4] Creating dist folder..." -ForegroundColor Yellow

if (Test-Path $distPath) {
    Remove-Item -Path $distPath -Recurse -Force
}
New-Item -Path $distPath -ItemType Directory -Force | Out-Null

Write-Host "        $distPath" -ForegroundColor DarkGray
#endregion

#region Build Bundle
Write-Host "  [2/4] Building repo-nav-bundle.ps1..." -ForegroundColor Yellow

# Define the exact load order (matches repo-nav.ps1 import order)
$loadOrder = @(
    # Layer 1: Config
    "Config\Constants.ps1",
    "Config\ColorPalette.ps1",
    
    # Layer 2: Models
    "Models\GitStatusModel.ps1",
    "Models\AliasInfo.ps1",
    "Models\RepositoryModel.ps1",
    "Models\IntegrationFlowModel.ps1",
    "Core\Common\OperationResult.ps1",
    
    # Layer 3: Core Infrastructure
    "Core\Interfaces\IProgressReporter.ps1",
    "Services\WindowSizeCalculator.ps1",
    "Core\State\NavigationState.ps1",
    
    # Layer 4: Services
    "Services\ConfigurationService.ps1",
    "Services\UserPreferencesService.ps1",
    "Services\LocalizationService.ps1",
    "Services\AliasManager.ps1",
    "Services\GitReadService.ps1",
    "Services\GitWriteService.ps1",
    "Services\GitService.ps1",
    "Services\NpmService.ps1",
    "Services\ParallelGitLoader.ps1",
    "Services\RepositoryOperationsService.ps1",
    "Services\FavoriteService.ps1",
    "Services\SearchService.ps1",
    "Services\RenderOrchestrator.ps1",
    "Services\LoggerService.ps1",
    
    # Layer 5: UI Base & Framework
    "UI\Base\ConsoleHelper.ps1",
    "UI\Framework\ConsoleView.ps1",
    
    # Layer 6: UI Components
    "UI\ViewModels\RepositoryViewModel.ps1",
    "UI\UIRenderer.ps1",
    "UI\Components\ProgressIndicator.ps1",
    "UI\Components\ColorSelector.ps1",
    "UI\Components\OptionSelector.ps1",
    "UI\Renderers\FilteredListRenderer.ps1",
    "UI\Renderers\IntegrationFlowRenderer.ps1",
    "UI\Components\FilteredListSelector.ps1",
    "UI\Dashboards\IntegrationFlowDashboard.ps1",
    "UI\Services\ConsoleProgressReporter.ps1",
    
    # Layer 7: Core Managers
    "Core\Services\GitStatusManager.ps1",
    "Core\Services\RepositorySorter.ps1",
    "Core\RepositoryManager.ps1",
    
    # Layer 8: UI Controllers & Views
    "UI\Controllers\PreferencesMenuController.ps1",
    "UI\Views\RepositoryManagementView.ps1",
    "UI\Views\AliasView.ps1",
    "UI\Views\SearchView.ps1",
    
    # Layer 9: Commands
    "Core\State\CommandContext.ps1",
    "Core\Commands\INavigationCommand.ps1",
    "Core\Commands\ExitCommand.ps1",
    "Core\Commands\NavigationCommand.ps1",
    "Core\Commands\RepositoryCommand.ps1",
    "Core\Commands\GitCommand.ps1",
    "Core\Commands\FavoriteCommand.ps1",
    "Core\Commands\AliasCommand.ps1",
    "Core\Commands\NpmCommand.ps1",
    "Core\Commands\RepositoryManagementCommand.ps1",
    "Core\Commands\PreferencesCommand.ps1",
    "Core\Commands\CreateFolderCommand.ps1",
    "Core\Commands\SearchCommand.ps1",
    
    # Layer 10: Flows
    "Core\Flows\FlowControllerBase.ps1",
    "Core\Flows\IntegrationFlowController.ps1",
    "Core\Flows\QuickChangeFlowController.ps1",
    "Core\Flows\GitFlowCommand.ps1",
    
    # Layer 11: Engine
    "Core\Engine\CommandFactory.ps1",
    "Core\Engine\InputHandler.ps1",
    "Core\Engine\NavigationLoop.ps1",
    
    # Layer 12: Startup
    "Startup\ServiceRegistry.ps1",
    "App\AppBuilder.ps1"
)

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

foreach ($relativePath in $loadOrder) {
    $fullPath = Join-Path $srcPath $relativePath
    
    if (-not (Test-Path $fullPath)) {
        Write-Host "        [WARN] Missing: $relativePath" -ForegroundColor Yellow
        continue
    }
    
    $fileContent = Get-Content $fullPath -Raw -Encoding UTF8
    
    # ─────────────────────────────────────────────────────────────────────
    # BUILD TRANSFORMATIONS: Adapt development paths to bundle paths
    # ─────────────────────────────────────────────────────────────────────
    # Resources path: src\Resources\i18n → Resources\i18n
    $fileContent = $fileContent -replace 'src\\Resources\\i18n', 'Resources\i18n'
    $fileContent = $fileContent -replace 'src/Resources/i18n', 'Resources/i18n'
    
    [void]$bundleContent.AppendLine("#region $relativePath")
    
    if ($Minify) {
        $lines = $fileContent -split "`n" | Where-Object { 
            $trimmed = $_.Trim()
            $trimmed -ne '' -and -not ($trimmed -match '^#(?!>)') -and -not ($trimmed -match '^<#')
        }
        $fileContent = $lines -join "`n"
    }
    
    [void]$bundleContent.AppendLine($fileContent)
    [void]$bundleContent.AppendLine("#endregion")
    [void]$bundleContent.AppendLine("")
    
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
Write-Host "  [3/4] Generating Setup-Bundle.ps1..." -ForegroundColor Yellow

# Copy the original Setup.ps1 and modify it for bundle
$originalSetup = Get-Content (Join-Path $scriptRoot "Setup.ps1") -Raw -Encoding UTF8

# Replace reference to repo-nav.ps1 with repo-nav-bundle.ps1
$distSetup = $originalSetup -replace 'repo-nav\.ps1', 'repo-nav-bundle.ps1'

$setupPath = Join-Path $distPath "Setup-Bundle.ps1"
$distSetup | Set-Content -Path $setupPath -Encoding UTF8 -Force

Write-Host "        Setup-Bundle.ps1 generated" -ForegroundColor DarkGray
#endregion

#region Copy Resources (translations)
Write-Host "  [4/4] Copying Resources (translations)..." -ForegroundColor Yellow

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

#region Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  BUILD COMPLETE!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Distribution folder: $distPath" -ForegroundColor White
Write-Host ""
Write-Host "  Contents:" -ForegroundColor Cyan
Write-Host "    - repo-nav-bundle.ps1  ($bundleSize KB)" -ForegroundColor Gray
Write-Host "    - Setup-Bundle.ps1" -ForegroundColor Gray
Write-Host "    - Resources/i18n/      (translations)" -ForegroundColor Gray
Write-Host ""
Write-Host "  To distribute:" -ForegroundColor Yellow
Write-Host "    1. Copy the 'dist' folder to target machine" -ForegroundColor Gray
Write-Host "    2. Run: .\Setup-Bundle.ps1" -ForegroundColor Gray
Write-Host ""
#endregion
