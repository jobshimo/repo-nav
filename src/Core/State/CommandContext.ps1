class CommandContext {
    [NavigationState] $State
    [RepositoryManager] $RepoManager
    [UIRenderer] $Renderer
    [ConsoleHelper] $Console
    [LoggerService] $Logger
    [ColorSelector] $ColorSelector
    [OptionSelector] $OptionSelector
    [LocalizationService] $LocalizationService
    [UserPreferencesService] $PreferencesService
    [HiddenReposService] $HiddenReposService
    [string] $BasePath
}
