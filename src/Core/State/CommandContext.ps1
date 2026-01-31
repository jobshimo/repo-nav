class CommandContext {
    [INavigationState] $State
    [IRepositoryManager] $RepoManager
    [IUIRenderer] $Renderer
    [IConsoleHelper] $Console
    [LoggerService] $Logger
    [ColorSelector] $ColorSelector
    [OptionSelector] $OptionSelector
    [LocalizationService] $LocalizationService
    [UserPreferencesService] $PreferencesService
    [HiddenReposService] $HiddenReposService
    [PathManager] $PathManager
    [string] $BasePath
}
