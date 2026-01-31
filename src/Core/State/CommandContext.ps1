class CommandContext {
    [NavigationState] $State
    [IRepositoryManager] $RepoManager
    [UIRenderer] $Renderer
    [ConsoleHelper] $Console
    [LoggerService] $Logger
    [ColorSelector] $ColorSelector
    [OptionSelector] $OptionSelector
    [LocalizationService] $LocalizationService
    [UserPreferencesService] $PreferencesService
    [HiddenReposService] $HiddenReposService
    [PathManager] $PathManager
    [string] $BasePath
}
