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

# OPTIMIZATION: Scan all files at once to avoid multiple file system hits
# This reduces I/O latency significantly (~1s -> ~50ms)
$allFiles = Get-ChildItem -Path $srcPath -Recurse -Filter "*.ps1" -File

# Helper for in-memory filtering (faster than Get-ChildItem)
function Get-FilesInMemory {
    param([string]$subfolder)
    $targetPath = Join-Path $srcPath $subfolder
    return $allFiles | Where-Object { $_.DirectoryName -eq $targetPath }
}

# 1. Configuration (Constants, Palettes)
Get-FilesInMemory "Config" | ForEach-Object { . $_.FullName }

# 2. Models (Data structures, no dependencies)
Get-FilesInMemory "Models" | ForEach-Object { . $_.FullName }

# 3. Services (Business logic, depends on Models/Config)
# Explicit load for base services
$servicesPath = Join-Path $srcPath "Services"
. (Join-Path $servicesPath "ConfigurationService.ps1")
. (Join-Path $servicesPath "UserPreferencesService.ps1")
. (Join-Path $servicesPath "LocalizationService.ps1")
. (Join-Path $servicesPath "GitService.ps1")
. (Join-Path $servicesPath "WindowSizeCalculator.ps1")

$servicesExcluded = @(
    "ConfigurationService.ps1", "UserPreferencesService.ps1", 
    "LocalizationService.ps1", "GitService.ps1", "WindowSizeCalculator.ps1"
)
Get-FilesInMemory "Services" | ForEach-Object {
    if ($_.Name -notin $servicesExcluded) {
        . $_.FullName
    }
}

# 4. Core Level 1: State & Base Logic
. (Join-Path $srcPath "Core\NavigationState.ps1")

# 5. UI Layer
# Explicit order for Helpers
. (Join-Path $srcPath "UI\ConsoleHelper.ps1")

# Independent Renderers
. (Join-Path $srcPath "UI\ProgressIndicator.ps1")
. (Join-Path $srcPath "UI\ColorRenderer.ps1")
. (Join-Path $srcPath "UI\FeedbackRenderer.ps1")
. (Join-Path $srcPath "UI\HeaderRenderer.ps1")
. (Join-Path $srcPath "UI\MenuRenderer.ps1")
. (Join-Path $srcPath "UI\RepositoryListRenderer.ps1")
. (Join-Path $srcPath "UI\StatusRenderer.ps1")

# Main Facade
. (Join-Path $srcPath "UI\UIRenderer.ps1")

# Widgets
. (Join-Path $srcPath "UI\ColorSelector.ps1")
. (Join-Path $srcPath "UI\OptionSelector.ps1")

$uiExcluded = @(
    "ConsoleHelper.ps1", "ProgressIndicator.ps1", "ColorRenderer.ps1",
    "FeedbackRenderer.ps1", "HeaderRenderer.ps1", "MenuRenderer.ps1",
    "RepositoryListRenderer.ps1", "StatusRenderer.ps1", "UIRenderer.ps1",
    "ColorSelector.ps1", "OptionSelector.ps1"
)
Get-FilesInMemory "UI" | ForEach-Object {
    if ($_.Name -notin $uiExcluded) {
        . $_.FullName
    }
}

Get-FilesInMemory "UI\Views" | ForEach-Object { . $_.FullName }


# 6. Core Level 2: Managers & Context
. (Join-Path $srcPath "Core\RepositoryManager.ps1")
. (Join-Path $srcPath "Core\CommandContext.ps1")
. (Join-Path $srcPath "Core\ApplicationContext.ps1")

# 7. Core Level 3: Commands
. (Join-Path $srcPath "Core\Commands\INavigationCommand.ps1")
Get-FilesInMemory "Core\Commands" | ForEach-Object {
    if ($_.Name -ne "INavigationCommand.ps1") {
        . $_.FullName
    }
}

# 8. Core Level 4: Orchestration
. (Join-Path $srcPath "Core\CommandFactory.ps1")
. (Join-Path $srcPath "Core\InputHandler.ps1")
. (Join-Path $srcPath "Core\NavigationLoop.ps1")

# 9. Bootstrapper (Composition Root)
. (Join-Path $srcPath "Core\Bootstrapper.ps1")

# Any remaining files in Core
$coreExcluded = @(
    "NavigationState.ps1", "RepositoryManager.ps1", "CommandContext.ps1", "ApplicationContext.ps1",
    "CommandFactory.ps1", "InputHandler.ps1", "NavigationLoop.ps1",
    "Bootstrapper.ps1", "DependencyLoader.ps1"
)
Get-FilesInMemory "Core" | ForEach-Object {
    if ($_.Name -notin $coreExcluded) {
        . $_.FullName
    }
}

Write-Host "Dependencies loaded." -ForegroundColor DarkGray
