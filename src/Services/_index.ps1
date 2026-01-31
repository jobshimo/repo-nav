# ============================================================================
# Services Layer Index
# ============================================================================
# Dependencies: Config, Models, Core/Interfaces, Core/State/NavigationState
# ============================================================================

$servicesPath = $PSScriptRoot

# Helpers first (no dependencies)
. "$servicesPath\ArrayHelper.ps1"

# Base services
. "$servicesPath\ConfigurationService.ps1"
. "$servicesPath\UserPreferencesService.ps1"
. "$servicesPath\LocalizationService.ps1"
. "$servicesPath\AliasManager.ps1"
. "$servicesPath\LoggerService.ps1"
. "$servicesPath\ErrorHandler.ps1"

# Git services
. "$servicesPath\GitService.ps1"
. "$servicesPath\GitReadService.ps1"
. "$servicesPath\GitWriteService.ps1"

# Other services
. "$servicesPath\NpmService.ps1"
. "$servicesPath\ParallelGitLoader.ps1"
. "$servicesPath\RepositoryOperationsService.ps1"
. "$servicesPath\FavoriteService.ps1"
. "$servicesPath\HiddenReposService.ps1"
. "$servicesPath\SearchService.ps1"
. "$servicesPath\RenderOrchestrator.ps1"
