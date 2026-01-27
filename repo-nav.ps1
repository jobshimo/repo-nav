<#
.SYNOPSIS
    Interactive repository navigator for managing multiple Git repositories

.DESCRIPTION
    Navigate between repositories, manage aliases, install/remove node_modules,
    clone repositories from GitHub, and delete repositories with safety checks.
    
    This version has been refactored using SOLID principles and OOP:
    - Single Responsibility Principle: Each class has one clear purpose
    - Open/Closed Principle: Easy to extend without modifying existing code
    - Liskov Substitution Principle: Proper inheritance and composition
    - Interface Segregation Principle: Specialized interfaces for UI, Services
    - Dependency Inversion Principle: All classes depend on abstractions

.PARAMETER BasePath
    The base path where repositories are located. If not provided, uses the default from Constants.

.EXAMPLE
    .\repo-nav.ps1
    Launches with default path from Constants.ps1

.EXAMPLE
    .\repo-nav.ps1 -BasePath "C:\Projects"
    Launches with custom repositories path

.INSTALLATION
    Run .\Install.ps1 for interactive setup

.USAGE
    Type your command (e.g., 'list') from any directory to launch the repository navigator

.CONTROLS
    Navigation: Arrows | Enter=open | Q=quit
    Aliases:    E=set | R=remove
    Modules:    I=install | X=remove
    Repository: C=clone | Del=delete
    Git Status: L=load current | G=load all

.NOTES
    Author: Martin Miguel Bernal Garcia
    Version: 2.0 (Refactored with SOLID/OOP)
    Requires: PowerShell 5.1+, Git, npm (for node_modules management)
#>

# Parameters must be at the top of the script
param(
    [Parameter(Mandatory=$false)]
    [string]$BasePath
)

#region Import Modules
# Get script directory
$scriptRoot = $PSScriptRoot
$srcPath = Join-Path $scriptRoot "src"

# Import in dependency order
# Config
. "$srcPath\Config\Constants.ps1"
. "$srcPath\Config\ColorPalette.ps1"

# Initialize Constants with configuration
[Constants]::Initialize($scriptRoot)

# Models (no dependencies)
. "$srcPath\Models\GitStatusModel.ps1"
. "$srcPath\Models\AliasInfo.ps1"
. "$srcPath\Models\RepositoryModel.ps1"

# Services - WindowSizeCalculator needed by NavigationState
. "$srcPath\Services\WindowSizeCalculator.ps1"

# Core - Navigation State (Accessed by UI and Services)
. "$srcPath\Core\State\NavigationState.ps1"

# Services (depend on models)
. "$srcPath\Services\ConfigurationService.ps1"
. "$srcPath\Services\UserPreferencesService.ps1"
. "$srcPath\Services\LocalizationService.ps1"
. "$srcPath\Services\AliasManager.ps1"
. "$srcPath\Services\GitService.ps1"
. "$srcPath\Services\NpmService.ps1"
. "$srcPath\Services\ParallelGitLoader.ps1"
. "$srcPath\Services\RepositoryOperationsService.ps1"
. "$srcPath\Services\FavoriteService.ps1"
. "$srcPath\Services\SearchService.ps1"
. "$srcPath\Services\RenderOrchestrator.ps1"
. "$srcPath\Services\LoggerService.ps1"

# UI (depend on models and config)
# UI (depend on models and config)
. "$srcPath\UI\Base\ConsoleHelper.ps1"
. "$srcPath\UI\Components\ProgressIndicator.ps1"
. "$srcPath\UI\UIRenderer.ps1"
. "$srcPath\UI\Components\ColorSelector.ps1"
. "$srcPath\UI\Components\OptionSelector.ps1"
. "$srcPath\UI\Renderers\FilteredListRenderer.ps1"
. "$srcPath\UI\Renderers\IntegrationFlowRenderer.ps1"
. "$srcPath\UI\Components\FilteredListSelector.ps1"
# RepositoryManager (Depends on Services AND UI Components like ProgressIndicator)
. "$srcPath\Core\RepositoryManager.ps1"

# Controllers (Depend on RepositoryManager and UI)
. "$srcPath\UI\Controllers\PreferencesMenuController.ps1"

# Views (depend on UI components)
. "$srcPath\UI\Views\RepositoryManagementView.ps1"
. "$srcPath\UI\Views\AliasView.ps1"
. "$srcPath\UI\Views\SearchView.ps1"

# Core Context (Depends on RepositoryManager and UI)
. "$srcPath\Core\State\CommandContext.ps1"

# Commands (Interfaces and Implementations)
. "$srcPath\Core\Commands\INavigationCommand.ps1"
. "$srcPath\Core\Commands\ExitCommand.ps1"
. "$srcPath\Core\Commands\NavigationCommand.ps1"
. "$srcPath\Core\Commands\RepositoryCommand.ps1"
. "$srcPath\Core\Commands\GitCommand.ps1"
. "$srcPath\Core\Commands\FavoriteCommand.ps1"
. "$srcPath\Core\Commands\AliasCommand.ps1"
. "$srcPath\Core\Commands\NpmCommand.ps1"
. "$srcPath\Core\Commands\RepositoryManagementCommand.ps1"
. "$srcPath\Core\Commands\PreferencesCommand.ps1"
. "$srcPath\Core\Commands\CreateFolderCommand.ps1"
. "$srcPath\Core\Commands\SearchCommand.ps1"
. "$srcPath\Core\Commands\GitFlowCommand.ps1"

# Core Components
# Core Components
. "$srcPath\Core\Engine\CommandFactory.ps1"
. "$srcPath\Core\Engine\InputHandler.ps1"
. "$srcPath\Core\Engine\NavigationLoop.ps1"

# App Builder (Manual DI Container)
. "$srcPath\App\AppBuilder.ps1"
#endregion

#region Main Entry Point
function Start-RepositoryNavigator {
    <#
    .SYNOPSIS
        Main entry point - creates all dependencies and starts the navigator
    .DESCRIPTION
        This function implements the Composition Root pattern:
        - Creates all service instances
        - Wires up dependencies
        - Starts the navigation loop
    #>
    
    param(
        [string]$BasePath = (Split-Path -Parent $PSScriptRoot)
    )
    
    try {
        # Build Application Context using Manual DI Container
        # This keeps the entry point clean and allows for easier testing/swapping in the future
        $appContext = [AppBuilder]::Build($BasePath)

        # Start navigation loop
        Start-NavigationLoop -Context $appContext
    }
    catch {
        Write-Host ""
        Write-Host "Error starting repository navigator:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""
        Write-Host "Stack trace:" -ForegroundColor DarkGray
        Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "Press any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}
#endregion

#region Execute
# When script is run directly (not dot-sourced), start the navigator
if ($MyInvocation.InvocationName -ne '.') {
    # Use provided BasePath or default from Constants
    if (-not $BasePath) {
        $BasePath = [Constants]::ReposBasePath
    }
    
    # Start the navigator
    Start-RepositoryNavigator -BasePath $BasePath
}
#endregion
