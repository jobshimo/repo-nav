class CommandContext {
    [NavigationState] $State
    [RepositoryManager] $RepoManager
    [UIRenderer] $Renderer
    [ConsoleHelper] $Console
    [ColorSelector] $ColorSelector
    [OptionSelector] $OptionSelector
    [LocalizationService] $LocalizationService
    [string] $BasePath
}
