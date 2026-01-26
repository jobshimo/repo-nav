<#
.SYNOPSIS
    Handles the ordered loading of all application dependencies.
    
.DESCRIPTION
    This script is responsible for loading all classes and scripts in the correct dependency order.
    It executes in the caller's scope (when dot-sourced), ensuring classes are globally available.
    
    Order:
    Config -> Models -> Services -> Core (State) -> UI -> Core (Managers) -> Commands -> Logic
#>

# Calculate SrcPath relative to this script location (src/Core)
$currentDir = $PSScriptRoot
$srcPath = Split-Path $currentDir -Parent

Write-Host "Loading dependencies..." -ForegroundColor DarkGray

# 1. Configuration (Constants, Palettes)
$configPath = Join-Path $srcPath "Config"
if (Test-Path $configPath) {
    Get-ChildItem -Path $configPath -Filter "*.ps1" -File | ForEach-Object {
        . $_.FullName
    }
}

# 2. Models (Data structures, no dependencies)
$modelsPath = Join-Path $srcPath "Models"
if (Test-Path $modelsPath) {
    Get-ChildItem -Path $modelsPath -Filter "*.ps1" -File | ForEach-Object {
        . $_.FullName
    }
}

# 3. Services (Business logic, depends on Models/Config)
# Order matters: Base services first
. (Join-Path $srcPath "Services\ConfigurationService.ps1")
. (Join-Path $srcPath "Services\UserPreferencesService.ps1")
. (Join-Path $srcPath "Services\LocalizationService.ps1")
. (Join-Path $srcPath "Services\GitService.ps1")
. (Join-Path $srcPath "Services\WindowSizeCalculator.ps1")

$servicesPath = Join-Path $srcPath "Services"
$servicesExcluded = @(
    "ConfigurationService.ps1", "UserPreferencesService.ps1", 
    "LocalizationService.ps1", "GitService.ps1", "WindowSizeCalculator.ps1"
)
if (Test-Path $servicesPath) {
    Get-ChildItem -Path $servicesPath -Filter "*.ps1" -File | ForEach-Object {
        if ($_.Name -notin $servicesExcluded) {
            . $_.FullName
        }
    }
}

# 4. Core Level 1: State & Base Logic
. (Join-Path $srcPath "Core\NavigationState.ps1")

# 5. UI Layer
# Depends on Models, Config, Services, and NavigationState
# Explicit order is critical for UI components:
# Helpers -> Independent Renderers -> Facade (UIRenderer) -> Interactive Widgets (Selectors)

# Base Helper
. (Join-Path $srcPath "UI\ConsoleHelper.ps1")

# Components (Independent of UIRenderer)
. (Join-Path $srcPath "UI\ProgressIndicator.ps1")
. (Join-Path $srcPath "UI\ColorRenderer.ps1")
. (Join-Path $srcPath "UI\FeedbackRenderer.ps1")
. (Join-Path $srcPath "UI\HeaderRenderer.ps1")
. (Join-Path $srcPath "UI\MenuRenderer.ps1")
. (Join-Path $srcPath "UI\RepositoryListRenderer.ps1")
. (Join-Path $srcPath "UI\StatusRenderer.ps1")

# Main Facade (Depends on components above)
. (Join-Path $srcPath "UI\UIRenderer.ps1")

# Interactive Widgets (Depend on UIRenderer or ConsoleHelper)
. (Join-Path $srcPath "UI\ColorSelector.ps1")
. (Join-Path $srcPath "UI\OptionSelector.ps1")

$uiPath = Join-Path $srcPath "UI"
$uiExcluded = @(
    "ConsoleHelper.ps1", "ProgressIndicator.ps1", "ColorRenderer.ps1",
    "FeedbackRenderer.ps1", "HeaderRenderer.ps1", "MenuRenderer.ps1",
    "RepositoryListRenderer.ps1", "StatusRenderer.ps1", "UIRenderer.ps1",
    "ColorSelector.ps1", "OptionSelector.ps1"
)

if (Test-Path $uiPath) {
    Get-ChildItem -Path $uiPath -Filter "*.ps1" -File | ForEach-Object {
        if ($_.Name -notin $uiExcluded) {
            . $_.FullName
        }
    }
}
$uiViewsPath = Join-Path $srcPath "UI\Views"
if (Test-Path $uiViewsPath) {
    Get-ChildItem -Path $uiViewsPath -Filter "*.ps1" -File | ForEach-Object {
        . $_.FullName
    }
}

# 6. Core Level 2: Managers & Context
. (Join-Path $srcPath "Core\RepositoryManager.ps1")
. (Join-Path $srcPath "Core\CommandContext.ps1")
. (Join-Path $srcPath "Core\ApplicationContext.ps1")

# 7. Core Level 3: Commands
. (Join-Path $srcPath "Core\Commands\INavigationCommand.ps1")
$commandsPath = Join-Path $srcPath "Core\Commands"
if (Test-Path $commandsPath) {
    Get-ChildItem -Path $commandsPath -Filter "*.ps1" -File | ForEach-Object {
        . $_.FullName
    }
}

# 8. Core Level 4: Orchestration
. (Join-Path $srcPath "Core\CommandFactory.ps1")
. (Join-Path $srcPath "Core\InputHandler.ps1")
. (Join-Path $srcPath "Core\NavigationLoop.ps1")

# 9. Bootstrapper (Composition Root)
. (Join-Path $srcPath "Core\Bootstrapper.ps1")

# Any remaining files in Core that weren't explicitly loaded
$corePath = Join-Path $srcPath "Core"
$coreExcluded = @(
    "NavigationState.ps1", "RepositoryManager.ps1", "CommandContext.ps1", "ApplicationContext.ps1",
    "CommandFactory.ps1", "InputHandler.ps1", "NavigationLoop.ps1",
    "Bootstrapper.ps1", "DependencyLoader.ps1"
)
if (Test-Path $corePath) {
    Get-ChildItem -Path $corePath -Filter "*.ps1" -File | ForEach-Object {
        if ($_.Name -notin $coreExcluded) {
            . $_.FullName
        }
    }
}

Write-Host "Dependencies loaded." -ForegroundColor DarkGray
