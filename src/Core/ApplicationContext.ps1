<#
.SYNOPSIS
    Container for the application-wide dependencies and context.
    
.DESCRIPTION
    This class replaces the generic PSCustomObject used in earlier versions.
    It provides strong typing for dependency injection into the main loop.
#>

class ApplicationContext {
    [RepositoryManager] $RepoManager
    [UIRenderer] $Renderer
    [ConsoleHelper] $Console
    [ColorSelector] $ColorSelector
    [OptionSelector] $OptionSelector
    [LocalizationService] $LocalizationService
    [UserPreferencesService] $PreferencesService
    [string] $BasePath

    # Constructor for easy instantiation
    ApplicationContext(
        [RepositoryManager] $repoManager,
        [UIRenderer] $renderer,
        [ConsoleHelper] $console,
        [ColorSelector] $colorSelector,
        [OptionSelector] $optionSelector,
        [LocalizationService] $localizationService,
        [UserPreferencesService] $preferencesService,
        [string] $basePath
    ) {
        $this.RepoManager = $repoManager
        $this.Renderer = $renderer
        $this.Console = $console
        $this.ColorSelector = $colorSelector
        $this.OptionSelector = $optionSelector
        $this.LocalizationService = $localizationService
        $this.PreferencesService = $preferencesService
        $this.BasePath = $basePath
    }
}
