class ApplicationContext {
    # Core Services
    [IRepositoryManager]        $RepoManager
    [ConfigurationService]      $ConfigurationService
    [UserPreferencesService]    $PreferencesService
    [LocalizationService]       $LocalizationService
    [PathManager]               $PathManager
    [HiddenReposService]       $HiddenReposService
    
    # UI & Infrastructure
    [IUIRenderer]               $Renderer
    [ConsoleHelper]             $Console
    [LoggerService]             $Logger
    [OptionSelector]            $OptionSelector
    [ColorSelector]             $ColorSelector
    [OnboardingService]         $OnboardingService
    
    # Context
    [string]                    $BasePath
    
    # Registry Access (Optional backup)
    [type]                      $ServiceRegistry

    ApplicationContext() {
    }
}
