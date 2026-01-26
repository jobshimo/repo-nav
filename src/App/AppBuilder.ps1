class AppBuilder {
    <#
    .SYNOPSIS
        Centralizes the wiring of all application services.
    .DESCRIPTION
        Manual Dependency Injection container (Performance First).
        Replaces dynamic reflection-based containers to ensure instant startup.
    #>
    static [PSCustomObject] Build([string]$BasePath) {
        # 0. Load Configuration (Centralized)
        $configService = [ConfigurationService]::new()
        try {
            $envConfig = $configService.LoadEnvironmentConfig()
            [Constants]::ReposBasePath = $envConfig.reposBasePath
            [Constants]::UserName = $envConfig.userName
            
            # If no BasePath provided by arguments, use config default
            if ([string]::IsNullOrWhiteSpace($BasePath)) {
                $BasePath = [Constants]::ReposBasePath
            }
        } catch {
            Write-Warning "Could not load environment config: $_"
        }

        # 1. Base Services (No dependencies)
        $gitService        = [GitService]::new()
        $npmService        = [NpmService]::new()
        # $configService already created above
        $preferencesService = [UserPreferencesService]::new()
        
        # 2. Localization (Depends on Config)
        $localizationService = [LocalizationService]::new()
        $language = $preferencesService.GetPreference("general", "language")
        $localizationService.SetLanguage($language)

        # 3. Intermediate Managers (Depend on Services)
        $aliasManager      = [AliasManager]::new($configService)
        $favoriteService   = [FavoriteService]::new($configService)
        $parallelGitLoader = [ParallelGitLoader]::new()
        $repoOpsService    = [RepositoryOperationsService]::new($gitService)
        
        # 4. Core Facade (Depends on everything above)
        $repoManager = [RepositoryManager]::new(
            $gitService,
            $npmService,
            $aliasManager,
            $configService,
            $preferencesService,
            $favoriteService,
            $parallelGitLoader,
            $repoOpsService
        )
        
        # 5. UI Layer
        $consoleHelper  = [ConsoleHelper]::new()
        $renderer       = [UIRenderer]::new($consoleHelper, $preferencesService, $localizationService)
        $colorSelector  = [ColorSelector]::new($renderer, $consoleHelper)
        $optionSelector = [OptionSelector]::new($consoleHelper, $renderer)
        
        # 6. Infrastructure (Logger)
        $logger = [LoggerService]::new([Constants]::ScriptRoot)
        
        # 7. Compose Application Context
        return [PSCustomObject]@{
            RepoManager         = $repoManager
            Renderer            = $renderer
            Console             = $consoleHelper
            Logger              = $logger
            ColorSelector       = $colorSelector
            OptionSelector      = $optionSelector
            LocalizationService = $localizationService
            PreferencesService  = $preferencesService
            BasePath            = $BasePath
        }
    }
}
