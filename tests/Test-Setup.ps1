<#
.SYNOPSIS
    Test Setup Script - Loads the entire application environment in the correct dependency order.
.DESCRIPTION
    Replicates the loading logic of repo-nav.ps1 to ensure all classes and types 
    are available before Pester runs any tests.
    
    Prevents "TypeNotFound" errors caused by Parse Time vs Runtime issues.
    Includes a guard to prevent re-loading if the environment is already active 
    (avoiding Class Redefinition errors).
#>

$scriptRoot = $PSScriptRoot
# If running from tests/ folder, go up one level to root. 
# If running from root context, adjust accordingly.
# Heuristic: verify if 'src' exists relative to $PSScriptRoot
if (Test-Path (Join-Path $scriptRoot "..\src")) {
    $rootPath = Resolve-Path (Join-Path $scriptRoot "..")
} else {
    $rootPath = $scriptRoot
}

$srcPath = Join-Path $rootPath "src"

Write-Host " [Test-Setup] Initializing Test Environment..." -ForegroundColor Cyan
Write-Host " [Test-Setup] Source Path: $srcPath" -ForegroundColor DarkGray

# -----------------------------------------------------------------------------
# GUARD: Check if environment is already loaded
# -----------------------------------------------------------------------------
# We check for a "Leaf" type (one of the last to be loaded) or a distinct Core type.
# GitFlowCommand is a good candidate as it depends on almost everything.
if ("GitFlowCommand" -as [type]) {
    Write-Host " [Test-Setup] Environment appears to be already loaded. Skipping load to avoid Class Redefinition." -ForegroundColor Yellow
    return
}

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 1: CONFIG
# ─────────────────────────────────────────────────────────────────────────────
Write-Host " [Test-Setup] Loading Layer 1: Config" -ForegroundColor DarkGray
. "$srcPath\Config\_index.ps1"
[Constants]::Initialize($rootPath)

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 2: MODELS
# ─────────────────────────────────────────────────────────────────────────────
Write-Host " [Test-Setup] Loading Layer 2: Models" -ForegroundColor DarkGray
. "$srcPath\Models\_index.ps1"

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 3: CORE INFRASTRUCTURE (Interfaces + State)
# ─────────────────────────────────────────────────────────────────────────────
Write-Host " [Test-Setup] Loading Layer 3: Core Infrastructure" -ForegroundColor DarkGray
# These must be loaded BEFORE Services
. "$srcPath\Core\Interfaces\IProgressReporter.ps1"
. "$srcPath\Core\Interfaces\IRepositoryManager.ps1"
. "$srcPath\Core\Interfaces\INavigationState.ps1"
. "$srcPath\Core\Interfaces\IWindowSizeCalculator.ps1"
. "$srcPath\Services\WindowSizeCalculator.ps1"
. "$srcPath\Core\State\NavigationState.ps1"
. "$srcPath\Core\Interfaces\IUIRenderer.ps1"
. "$srcPath\Core\Interfaces\IJobService.ps1"
. "$srcPath\Core\Interfaces\IConsoleHelper.ps1"
. "$srcPath\Core\Interfaces\ILoggerService.ps1"
. "$srcPath\Core\Interfaces\ILocalizationService.ps1"
. "$srcPath\Core\Interfaces\IUserPreferencesService.ps1"

. "$srcPath\Core\Interfaces\IParallelGitLoader.ps1"
. "$srcPath\Core\Interfaces\IHiddenReposService.ps1"
. "$srcPath\Core\Interfaces\IPathManager.ps1"
. "$srcPath\Core\Common\ConsoleView.ps1"
. "$srcPath\Core\Interfaces\IOptionSelector.ps1"
. "$srcPath\Core\Interfaces\IColorSelector.ps1"
. "$srcPath\Core\Interfaces\IProgressIndicator.ps1"
# NEW INTERFACES (Following SOLID Refactoring)
. "$srcPath\Core\Interfaces\INpmService.ps1"
. "$srcPath\Core\Interfaces\IGitService.ps1"
. "$srcPath\Core\Interfaces\IAliasManager.ps1"
. "$srcPath\Core\Interfaces\IFavoriteService.ps1"
. "$srcPath\Core\Interfaces\ISearchService.ps1"
. "$srcPath\Core\Interfaces\IRepositoryOperationsService.ps1"
. "$srcPath\Core\Interfaces\IGitStatusManager.ps1"
. "$srcPath\Core\Interfaces\IGitReadService.ps1"
. "$srcPath\Core\Interfaces\IGitWriteService.ps1"
. "$srcPath\Core\Interfaces\IViewportManager.ps1"
. "$srcPath\Core\Interfaces\IArrayHelper.ps1"
. "$srcPath\Core\Interfaces\IFilteredListRenderer.ps1"
. "$srcPath\Core\Interfaces\IIntegrationFlowDashboard.ps1"
. "$srcPath\Core\Interfaces\IIntegrationFlowRenderer.ps1"
. "$srcPath\Core\Interfaces\IPreferencesMenuRenderer.ps1"
. "$srcPath\Core\Interfaces\IPreferencesMenuController.ps1"
. "$srcPath\Core\Interfaces\IPreferencesActionDispatcher.ps1"
. "$srcPath\Startup\ServiceRegistry.ps1"

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 4: SERVICES
# ─────────────────────────────────────────────────────────────────────────────
Write-Host " [Test-Setup] Loading Layer 4: Services" -ForegroundColor DarkGray
. "$srcPath\Services\_index.ps1"

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 5: UI (Base + Components + Services)
# ─────────────────────────────────────────────────────────────────────────────
Write-Host " [Test-Setup] Loading Layer 5: UI" -ForegroundColor DarkGray
. "$srcPath\UI\_index.ps1"

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 6: CORE MANAGERS
# ─────────────────────────────────────────────────────────────────────────────
Write-Host " [Test-Setup] Loading Layer 6: Core Managers" -ForegroundColor DarkGray
. "$srcPath\Core\Services\GitStatusManager.ps1"
. "$srcPath\Core\Services\RepositorySorter.ps1"
. "$srcPath\Core\Services\OnboardingService.ps1"
. "$srcPath\Core\Services\PathManager.ps1"
. "$srcPath\Core\RepositoryManager.ps1"

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 7: UI CONTROLLERS & VIEWS
# ─────────────────────────────────────────────────────────────────────────────
Write-Host " [Test-Setup] Loading Layer 7: UI Controllers & Views" -ForegroundColor DarkGray
. "$srcPath\UI\Controllers\PreferencesActionDispatcher.ps1"
. "$srcPath\UI\Controllers\PreferencesMenuRenderer.ps1"
. "$srcPath\UI\Controllers\PreferencesMenuController.ps1"
. "$srcPath\UI\Views\RepositoryManagementView.ps1"
. "$srcPath\UI\Views\AliasView.ps1"
. "$srcPath\UI\Views\SearchView.ps1"

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 8: COMMAND SYSTEM
# ─────────────────────────────────────────────────────────────────────────────
Write-Host " [Test-Setup] Loading Layer 8: Command System" -ForegroundColor DarkGray
. "$srcPath\Core\State\ApplicationContext.ps1"
. "$srcPath\Core\State\CommandContext.ps1"
. "$srcPath\Core\Commands\_index.ps1"

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 9: FLOWS
# ─────────────────────────────────────────────────────────────────────────────
Write-Host " [Test-Setup] Loading Layer 9: Flows" -ForegroundColor DarkGray
. "$srcPath\Core\Flows\_index.ps1"

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 10: ENGINE
# ─────────────────────────────────────────────────────────────────────────────
Write-Host " [Test-Setup] Loading Layer 10: Engine" -ForegroundColor DarkGray
. "$srcPath\Core\Engine\_index.ps1"

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 11: STARTUP (Partial)
# ─────────────────────────────────────────────────────────────────────────────
Write-Host " [Test-Setup] Loading Layer 11: Startup" -ForegroundColor DarkGray
. "$srcPath\Startup\_index.ps1"

Write-Host " [Test-Setup] Environment Loaded Successfully." -ForegroundColor Green
