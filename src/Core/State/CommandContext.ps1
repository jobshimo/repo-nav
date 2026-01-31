class CommandContext {
    [INavigationState] $State
    [IRepositoryManager] $RepoManager
    [IUIRenderer] $Renderer
    [IConsoleHelper] $Console
    [ILoggerService] $Logger
    [IColorSelector] $ColorSelector
    [IOptionSelector] $OptionSelector
    [ILocalizationService] $LocalizationService
    [IUserPreferencesService] $PreferencesService
    [IHiddenReposService] $HiddenReposService
    [IPathManager] $PathManager
    [string] $BasePath
}
