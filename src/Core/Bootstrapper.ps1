<#
.SYNOPSIS
    Composition Root for the application.
    
.DESCRIPTION
    Responsible for:
    1. Instantiating all services and components
    2. Wiring dependencies (Dependency Injection)
    3. Starting the application loop
#>

class Bootstrapper {
    static [void] Start([string]$BasePath) {
        try {
            # 1. Services Layer
            $gitService = [GitService]::new()
            $npmService = [NpmService]::new()
            $configService = [ConfigurationService]::new()
            $preferencesService = [UserPreferencesService]::new()
            
            # Initialize Localization
            $localizationService = [LocalizationService]::new()
            $language = $preferencesService.GetPreference("general", "language")
            $localizationService.SetLanguage($language)

            # 2. Managers & Domain Services
            $aliasManager = [AliasManager]::new($configService)
            $favoriteService = [FavoriteService]::new($configService)
            $parallelGitLoader = [ParallelGitLoader]::new()
            $repoOperationsService = [RepositoryOperationsService]::new($gitService)
            
            # RepositoryManager (Facade)
            $repoManager = [RepositoryManager]::new(
                $gitService,
                $npmService,
                $aliasManager,
                $configService,
                $preferencesService,
                $favoriteService,
                $parallelGitLoader,
                $repoOperationsService
            )
            
            # 3. UI Layer
            $consoleHelper = [ConsoleHelper]::new()
            $menuRenderer = [MenuRenderer]::new($consoleHelper, $preferencesService, $localizationService)
            $repoListRenderer = [RepositoryListRenderer]::new($consoleHelper, $preferencesService)
            $statusRenderer = [StatusRenderer]::new($consoleHelper, $localizationService)
            $headerRenderer = [HeaderRenderer]::new($consoleHelper, $localizationService)
            $feedbackRenderer = [FeedbackRenderer]::new($consoleHelper, $localizationService)
            $colorRenderer = [ColorRenderer]::new($consoleHelper, $preferencesService, $localizationService)
            
            # Main Renderer (Facade)
            $renderer = [UIRenderer]::new(
                $consoleHelper, 
                $preferencesService, 
                $localizationService, 
                $menuRenderer, 
                $repoListRenderer, 
                $statusRenderer, 
                $headerRenderer, 
                $feedbackRenderer, 
                $colorRenderer
            )
            
            $colorSelector = [ColorSelector]::new($renderer, $consoleHelper)
            $optionSelector = [OptionSelector]::new($consoleHelper, $renderer)
            
            # 4. Application Context
            # We bundle everything needed by the NavigationLoop
            $appContext = [ApplicationContext]::new(
                $repoManager,
                $renderer,
                $consoleHelper,
                $colorSelector,
                $optionSelector,
                $localizationService,
                $preferencesService,
                $BasePath
            )

            # 5. Start Application
            Start-NavigationLoop -Context $appContext
        }
        catch {
            Write-Host ""
            Write-Host "CRITICAL ERROR during startup:" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
            Write-Host "Stack Trace:" -ForegroundColor Gray
            Write-Host $_.ScriptStackTrace -ForegroundColor Gray
            Write-Host ""
            Write-Host "Press any key to exit..."
            $null = $global:Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
    }
}
