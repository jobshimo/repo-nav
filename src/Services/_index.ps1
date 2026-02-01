# ============================================================================
# Services Layer Index
# ============================================================================
# Dependencies: Config, Models, Core/Interfaces, Core/State/NavigationState
# ============================================================================

$servicesPath = $PSScriptRoot

# Helpers first (no dependencies)
if (-not ([System.Management.Automation.PSTypeName]'ArrayHelper').Type) {
    . "$servicesPath\ArrayHelper.ps1"
}
if (-not ([System.Management.Automation.PSTypeName]'WindowSizeCalculator').Type) {
    . "$servicesPath\WindowSizeCalculator.ps1"
}

# Base services

if (-not ([System.Management.Automation.PSTypeName]'UserPreferencesService').Type) {
    . "$servicesPath\UserPreferencesService.ps1"
}
if (-not ([System.Management.Automation.PSTypeName]'LocalizationService').Type) {
    . "$servicesPath\LocalizationService.ps1"
}
if (-not ([System.Management.Automation.PSTypeName]'AliasManager').Type) {
    . "$servicesPath\AliasManager.ps1"
}
if (-not ([System.Management.Automation.PSTypeName]'LoggerService').Type) {
    . "$servicesPath\LoggerService.ps1"
}
if (-not ([System.Management.Automation.PSTypeName]'ErrorHandler').Type) {
    . "$servicesPath\ErrorHandler.ps1"
}

# Git services
if (-not ([System.Management.Automation.PSTypeName]'GitService').Type) {
    . "$servicesPath\GitService.ps1"
}
if (-not ([System.Management.Automation.PSTypeName]'GitReadService').Type) {
    . "$servicesPath\GitReadService.ps1"
}
if (-not ([System.Management.Automation.PSTypeName]'GitWriteService').Type) {
    . "$servicesPath\GitWriteService.ps1"
}

# Other services
if (-not ([System.Management.Automation.PSTypeName]'NpmService').Type) {
    . "$servicesPath\NpmService.ps1"
}
if (-not ([System.Management.Automation.PSTypeName]'ParallelGitLoader').Type) {
    . "$servicesPath\ParallelGitLoader.ps1"
}
if (-not ([System.Management.Automation.PSTypeName]'RepositoryOperationsService').Type) {
    . "$servicesPath\RepositoryOperationsService.ps1"
}
if (-not ([System.Management.Automation.PSTypeName]'FavoriteService').Type) {
    . "$servicesPath\FavoriteService.ps1"
}
if (-not ([System.Management.Automation.PSTypeName]'HiddenReposService').Type) {
    . "$servicesPath\HiddenReposService.ps1"
}
if (-not ([System.Management.Automation.PSTypeName]'SearchService').Type) {
    . "$servicesPath\SearchService.ps1"
}
if (-not ([System.Management.Automation.PSTypeName]'RenderOrchestrator').Type) {
    . "$servicesPath\RenderOrchestrator.ps1"
}
if (-not ([System.Management.Automation.PSTypeName]'JobService').Type) {
    . "$servicesPath\JobService.ps1"
}
