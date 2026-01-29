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
# ============================================================================
# IMPORT SYSTEM - Manual Dependency Order
# ============================================================================
# 
# ⚠️  FOR AI ASSISTANTS & DEVELOPERS:
#     When adding a NEW FILE, find the appropriate section below and add
#     your dot-source line. Sections are organized by layer and dependency.
#
#     RULES:
#     1. A file can ONLY use types defined in files ABOVE it
#     2. If you get "TypeNotFound", move your import AFTER the type's file
#     3. Models have NO dependencies, Services depend on Models, etc.
#
# ============================================================================

$scriptRoot = $PSScriptRoot
$srcPath = Join-Path $scriptRoot "src"

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 1: CONFIG (Loaded first - defines global constants)
# ─────────────────────────────────────────────────────────────────────────────
# ADD NEW CONFIG FILES HERE
. "$srcPath\Config\Constants.ps1"
. "$srcPath\Config\ColorPalette.ps1"

# Initialize Constants with configuration
[Constants]::Initialize($scriptRoot)

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 2: MODELS (Pure data structures, no dependencies)
# ─────────────────────────────────────────────────────────────────────────────
# ADD NEW MODELS HERE (src/Models/*.ps1)
. "$srcPath\Models\GitStatusModel.ps1"
. "$srcPath\Models\AliasInfo.ps1"
. "$srcPath\Models\RepositoryModel.ps1"
. "$srcPath\Models\IntegrationFlowModel.ps1"
. "$srcPath\Core\Common\OperationResult.ps1"

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 3: CORE INFRASTRUCTURE (Interfaces, State - minimal deps)
# ─────────────────────────────────────────────────────────────────────────────
# ADD NEW INTERFACES HERE (src/Core/Interfaces/*.ps1)
. "$srcPath\Core\Interfaces\IProgressReporter.ps1"

# State - NavigationState needed early by many components
. "$srcPath\Services\WindowSizeCalculator.ps1"
. "$srcPath\Core\State\NavigationState.ps1"

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 4: SERVICES (Business logic, external integrations)
# ─────────────────────────────────────────────────────────────────────────────
# ADD NEW SERVICES HERE (src/Services/*.ps1)
# Order: Base services first, then services that depend on them
. "$srcPath\Services\ConfigurationService.ps1"
. "$srcPath\Services\UserPreferencesService.ps1"
. "$srcPath\Services\LocalizationService.ps1"
. "$srcPath\Services\AliasManager.ps1"
. "$srcPath\Services\GitReadService.ps1"
. "$srcPath\Services\GitWriteService.ps1"
. "$srcPath\Services\GitService.ps1"
. "$srcPath\Services\NpmService.ps1"
. "$srcPath\Services\ParallelGitLoader.ps1"
. "$srcPath\Services\RepositoryOperationsService.ps1"
. "$srcPath\Services\FavoriteService.ps1"
. "$srcPath\Services\SearchService.ps1"
. "$srcPath\Services\RenderOrchestrator.ps1"
. "$srcPath\Services\LoggerService.ps1"

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 5: UI BASE & FRAMEWORK (Console helpers, base classes)
# ─────────────────────────────────────────────────────────────────────────────
# ADD NEW UI BASE CLASSES HERE
. "$srcPath\UI\Base\ConsoleHelper.ps1"
. "$srcPath\UI\Framework\ConsoleView.ps1"

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 6: UI COMPONENTS & VIEWS (Widgets, Renderers, Views)
# ─────────────────────────────────────────────────────────────────────────────
# ADD NEW UI COMPONENTS HERE (src/UI/Components/*.ps1, src/UI/Views/*.ps1)
# ViewModels first (used by Renderer)
. "$srcPath\UI\ViewModels\RepositoryViewModel.ps1"
. "$srcPath\UI\UIRenderer.ps1"
. "$srcPath\UI\Components\ProgressIndicator.ps1"
. "$srcPath\UI\Components\ColorSelector.ps1"
. "$srcPath\UI\Components\OptionSelector.ps1"
. "$srcPath\UI\Renderers\FilteredListRenderer.ps1"
. "$srcPath\UI\Renderers\IntegrationFlowRenderer.ps1"
. "$srcPath\UI\Components\FilteredListSelector.ps1"
. "$srcPath\UI\Dashboards\IntegrationFlowDashboard.ps1"

# UI Services (implements interfaces from Core)
. "$srcPath\UI\Services\ConsoleProgressReporter.ps1"

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 7: CORE MANAGERS (Depend on Services + IProgressReporter)
# ─────────────────────────────────────────────────────────────────────────────
# ADD NEW CORE SERVICES/MANAGERS HERE (src/Core/Services/*.ps1)
. "$srcPath\Core\Services\GitStatusManager.ps1"
. "$srcPath\Core\Services\RepositorySorter.ps1"
. "$srcPath\Core\RepositoryManager.ps1"

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 8: UI CONTROLLERS & VIEWS (Depend on RepositoryManager)
# ─────────────────────────────────────────────────────────────────────────────
# ADD NEW CONTROLLERS/VIEWS HERE
. "$srcPath\UI\Controllers\PreferencesMenuController.ps1"
. "$srcPath\UI\Views\RepositoryManagementView.ps1"
. "$srcPath\UI\Views\AliasView.ps1"
. "$srcPath\UI\Views\SearchView.ps1"

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 9: COMMAND SYSTEM (Depends on UI + Core)
# ─────────────────────────────────────────────────────────────────────────────
# CommandContext - depends on UI types
. "$srcPath\Core\State\CommandContext.ps1"

# Command Interface + Implementations
# ADD NEW COMMANDS HERE (src/Core/Commands/*.ps1)
# Don't forget to register in CommandFactory.ps1 -> GetAllCommands()
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
# NOTE: GitFlowCommand is loaded AFTER Flows (Section 10) because it depends on them

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 10: FLOWS (Workflow controllers - depend on Commands + UI)
# ─────────────────────────────────────────────────────────────────────────────
# ADD NEW FLOWS HERE (src/Core/Flows/*.ps1)
. "$srcPath\Core\Flows\FlowControllerBase.ps1"
. "$srcPath\Core\Flows\IntegrationFlowController.ps1"
. "$srcPath\Core\Flows\QuickChangeFlowController.ps1"

# GitFlowCommand MUST be loaded after Flows (uses IntegrationFlowController, QuickChangeFlowController)
. "$srcPath\Core\Commands\GitFlowCommand.ps1"

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 11: ENGINE (Navigation loop - loaded last, drives everything)
# ─────────────────────────────────────────────────────────────────────────────
. "$srcPath\Core\Engine\CommandFactory.ps1"
. "$srcPath\Core\Engine\InputHandler.ps1"
. "$srcPath\Core\Engine\NavigationLoop.ps1"

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 12: STARTUP (DI Container, AppBuilder - depends on everything)
# ─────────────────────────────────────────────────────────────────────────────
. "$srcPath\Startup\ServiceRegistry.ps1"
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
