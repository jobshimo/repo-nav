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
# IMPORT SYSTEM - Layer-based Indices
# ============================================================================
# 
# ⚠️  FOR AI ASSISTANTS & DEVELOPERS:
#     When adding a NEW FILE, add it to the appropriate _index.ps1 file
#     in the corresponding layer folder.
#
#     LAYER ORDER (DO NOT CHANGE):
#     1. Config      → src/Config/_index.ps1
#     2. Models      → src/Models/_index.ps1
#     3. Services    → src/Services/_index.ps1
#     4. UI          → src/UI/_index.ps1
#     5. Commands    → src/Core/Commands/_index.ps1
#     6. Flows       → src/Core/Flows/_index.ps1 (includes GitFlowCommand)
#     7. Engine      → src/Core/Engine/_index.ps1
#     8. Startup     → src/Startup/_index.ps1
#
# ============================================================================

$scriptRoot = $PSScriptRoot
$srcPath = Join-Path $scriptRoot "src"

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 1: CONFIG
# ─────────────────────────────────────────────────────────────────────────────
. "$srcPath\Config\_index.ps1"
[Constants]::Initialize($scriptRoot)

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 2: MODELS
# ─────────────────────────────────────────────────────────────────────────────
. "$srcPath\Models\_index.ps1"

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 3: CORE INFRASTRUCTURE (Interfaces + State)
# ─────────────────────────────────────────────────────────────────────────────
. "$srcPath\Core\Interfaces\IProgressReporter.ps1"
. "$srcPath\Core\Interfaces\IRepositoryManager.ps1"
. "$srcPath\Core\Interfaces\INavigationState.ps1"
. "$srcPath\Services\WindowSizeCalculator.ps1"
. "$srcPath\Core\State\NavigationState.ps1"
. "$srcPath\Core\Interfaces\IJobService.ps1"
. "$srcPath\Core\Interfaces\IUIRenderer.ps1"
. "$srcPath\Core\Interfaces\IConsoleHelper.ps1"
. "$srcPath\Core\Interfaces\INavigationState.ps1"
. "$srcPath\Core\Interfaces\ILoggerService.ps1"
. "$srcPath\Core\Interfaces\ILocalizationService.ps1"
. "$srcPath\Core\Interfaces\IUserPreferencesService.ps1"
. "$srcPath\Core\Interfaces\IConfigurationService.ps1"
. "$srcPath\Core\Interfaces\IParallelGitLoader.ps1"
. "$srcPath\Core\Interfaces\IHiddenReposService.ps1"
. "$srcPath\Core\Interfaces\IPathManager.ps1"
. "$srcPath\Core\Common\ConsoleView.ps1"
. "$srcPath\Core\Interfaces\IOptionSelector.ps1"
. "$srcPath\Core\Interfaces\IColorSelector.ps1"
. "$srcPath\Core\Interfaces\IProgressIndicator.ps1"
. "$srcPath\Startup\ServiceRegistry.ps1"

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 4: SERVICES
# ─────────────────────────────────────────────────────────────────────────────
. "$srcPath\Services\_index.ps1"

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 5: UI (Base + Components + Services)
# ─────────────────────────────────────────────────────────────────────────────
. "$srcPath\UI\_index.ps1"

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 6: CORE MANAGERS
# ─────────────────────────────────────────────────────────────────────────────
. "$srcPath\Core\Services\GitStatusManager.ps1"
. "$srcPath\Core\Services\RepositorySorter.ps1"
. "$srcPath\Core\Services\OnboardingService.ps1"
. "$srcPath\Core\Services\PathManager.ps1"
. "$srcPath\Core\RepositoryManager.ps1"

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 7: UI CONTROLLERS & VIEWS
# ─────────────────────────────────────────────────────────────────────────────
. "$srcPath\UI\Controllers\PreferencesActionDispatcher.ps1"
. "$srcPath\UI\Controllers\PreferencesMenuRenderer.ps1"
. "$srcPath\UI\Controllers\PreferencesMenuController.ps1"
. "$srcPath\UI\Views\RepositoryManagementView.ps1"
. "$srcPath\UI\Views\AliasView.ps1"
. "$srcPath\UI\Views\SearchView.ps1"

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 8: COMMAND SYSTEM
# ─────────────────────────────────────────────────────────────────────────────
. "$srcPath\Core\State\ApplicationContext.ps1"
. "$srcPath\Core\State\CommandContext.ps1"
. "$srcPath\Core\Commands\_index.ps1"

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 9: FLOWS (includes GitFlowCommand)
# ─────────────────────────────────────────────────────────────────────────────
. "$srcPath\Core\Flows\_index.ps1"

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 10: ENGINE
# ─────────────────────────────────────────────────────────────────────────────
. "$srcPath\Core\Engine\_index.ps1"

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 11: STARTUP
# ─────────────────────────────────────────────────────────────────────────────
. "$srcPath\Startup\_index.ps1"

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
        [string]$BasePath
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
    # If no base path provided, check preferences or use default
    if (-not $BasePath) {
        # 1. Try to load from preferences
        try {
            $tempPrefs = [UserPreferencesService]::new()
            $defPath = $tempPrefs.GetPreference("repository", "defaultPath")
            
            if (-not [string]::IsNullOrWhiteSpace($defPath) -and (Test-Path $defPath)) {
                $BasePath = $defPath
            }
        } catch {}
        
    
    }
    
    # Start the navigator
    Start-RepositoryNavigator -BasePath $BasePath
}
#endregion
