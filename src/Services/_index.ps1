# ============================================================================
# Services Layer Index
# ============================================================================
# Dependencies: Config, Models, Core/Interfaces, Core/State/NavigationState
# ============================================================================

$servicesPath = $PSScriptRoot

# Base services first
. "$servicesPath\ConfigurationService.ps1"
. "$servicesPath\UserPreferencesService.ps1"
. "$servicesPath\LocalizationService.ps1"
. "$servicesPath\AliasManager.ps1"

# Git services
. "$servicesPath\GitReadService.ps1"
. "$servicesPath\GitWriteService.ps1"
. "$servicesPath\GitService.ps1"

# Other services
. "$servicesPath\NpmService.ps1"
. "$servicesPath\ParallelGitLoader.ps1"
. "$servicesPath\RepositoryOperationsService.ps1"
. "$servicesPath\FavoriteService.ps1"
. "$servicesPath\SearchService.ps1"
. "$servicesPath\RenderOrchestrator.ps1"
. "$servicesPath\LoggerService.ps1"
