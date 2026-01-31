class ApplicationContext {
    # Core Services
    [IRepositoryManager]        $RepoManager
    [ConfigurationService]      $ConfigurationService
    [IUserPreferencesService]    $PreferencesService
    [ILocalizationService]       $LocalizationService
    [IPathManager]               $PathManager
    [IHiddenReposService]       $HiddenReposService
    
    # UI & Infrastructure
    [IUIRenderer]               $Renderer
    [IConsoleHelper]             $Console
    [ILoggerService]             $Logger
    [IOptionSelector]            $OptionSelector
    [IColorSelector]             $ColorSelector
    [OnboardingService]         $OnboardingService
    
    # Context
    [string]                    $BasePath
    
    # Registry Access (Optional backup)
    [type]                      $ServiceRegistry

    ApplicationContext() {
    }
}
