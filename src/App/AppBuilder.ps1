class AppBuilder {
    <#
    .SYNOPSIS
        Centralizes the wiring of all application services.
    .DESCRIPTION
        Manual Dependency Injection container (Performance First).
        Replaces dynamic reflection-based containers to ensure instant startup.
    #>
    static [PSCustomObject] Build([string]$BasePath) {
        # Reset registry for clean start
        [ServiceRegistry]::Reset()

        # 0. Load Configuration (Centralized)
        $configService = [ConfigurationService]::new()
        [ServiceRegistry]::Register('ConfigurationService', $configService)

        # 1. Base Services (No dependencies)
        [ServiceRegistry]::Register('GitService', [GitService]::new())
        [ServiceRegistry]::Register('GitReadService', [GitReadService]::new())
        [ServiceRegistry]::Register('GitWriteService', [GitWriteService]::new())
        [ServiceRegistry]::Register('NpmService', [NpmService]::new())
        [ServiceRegistry]::Register('UserPreferencesService', [UserPreferencesService]::new())
        
        # 2. Localization (Depends on Config)
        $localizationService = [LocalizationService]::new()
        [ServiceRegistry]::Register('LocalizationService', $localizationService)
        
        $preferencesService = [ServiceRegistry]::Resolve('UserPreferencesService')
        $language = $preferencesService.GetPreference("general", "language")
        $localizationService.SetLanguage($language)

        # 3. Intermediate Managers (Depend on Services)
        [ServiceRegistry]::Register('AliasManager', [AliasManager]::new($configService))
        [ServiceRegistry]::Register('FavoriteService', [FavoriteService]::new($configService))
        [ServiceRegistry]::Register('HiddenReposService', [HiddenReposService]::new($preferencesService))
        [ServiceRegistry]::Register('ParallelGitLoader', [ParallelGitLoader]::new())
        
        $gitService = [ServiceRegistry]::Resolve('GitService')
        [ServiceRegistry]::Register('RepositoryOperationsService', [RepositoryOperationsService]::new($gitService))
        
        # 3b. Infrastructure / UI Abstractions
        $consoleHelper = [ConsoleHelper]::new()
        [ServiceRegistry]::Register('ConsoleHelper', $consoleHelper)
        
        $progressReporter = [ConsoleProgressReporter]::new($consoleHelper)
        [ServiceRegistry]::Register('IProgressReporter', $progressReporter)
        
        # 3c. Git Status Manager
        $gitStatusManager = [GitStatusManager]::new(
            $gitService,
            [ServiceRegistry]::Resolve('ParallelGitLoader'),
            $preferencesService,
            $progressReporter
        )
        [ServiceRegistry]::Register('GitStatusManager', $gitStatusManager)
        
        # 3d. Repository Sorter
        [ServiceRegistry]::Register('RepositorySorter', [RepositorySorter]::new())
        
        # 4. Core Facade (Depends on everything above)
        $repoManager = [RepositoryManager]::new(
            $gitService,
            [ServiceRegistry]::Resolve('GitReadService'),
            [ServiceRegistry]::Resolve('GitWriteService'),
            [ServiceRegistry]::Resolve('NpmService'),
            [ServiceRegistry]::Resolve('AliasManager'),
            $configService,
            $preferencesService,
            [ServiceRegistry]::Resolve('FavoriteService'),
            [ServiceRegistry]::Resolve('ParallelGitLoader'),
            [ServiceRegistry]::Resolve('RepositoryOperationsService'),
            $progressReporter,
            $gitStatusManager,
            [ServiceRegistry]::Resolve('RepositorySorter'),
            [ServiceRegistry]::Resolve('HiddenReposService')
        )
        [ServiceRegistry]::Register('RepositoryManager', $repoManager)
        
        # 5. UI Layer
        $renderer = [UIRenderer]::new($consoleHelper, $preferencesService, $localizationService)
        [ServiceRegistry]::Register('UIRenderer', $renderer)
        
        $optionSelector = [OptionSelector]::new($consoleHelper, $renderer)
        [ServiceRegistry]::Register('OptionSelector', $optionSelector)
        
        $colorSelector = [ColorSelector]::new($renderer, $consoleHelper, $optionSelector)
        [ServiceRegistry]::Register('ColorSelector', $colorSelector)
        
        # 5b. Onboarding Service
        $onboardingService = [OnboardingService]::new(
            $renderer,
            $consoleHelper,
            $localizationService,
            $optionSelector,
            $preferencesService
        )
        [ServiceRegistry]::Register('OnboardingService', $onboardingService)
        
        # 5c. Path Manager (Single Source of Truth for paths)
        $pathManager = [PathManager]::new($preferencesService)
        [ServiceRegistry]::Register('PathManager', $pathManager)
        
        # 6. Infrastructure (Logger)
        $logger = [LoggerService]::new([Constants]::ScriptRoot)
        [ServiceRegistry]::Register('LoggerService', $logger)
        
        # 7. Compose Application Context
        $context = [PSCustomObject]@{
            RepoManager         = $repoManager
            Renderer            = $renderer
            Console             = $consoleHelper
            Logger              = $logger
            ColorSelector       = $colorSelector
            OptionSelector      = $optionSelector
            OnboardingService   = $onboardingService
            PathManager         = $pathManager
            LocalizationService = $localizationService
            PreferencesService  = $preferencesService
            HiddenReposService  = [ServiceRegistry]::Resolve('HiddenReposService')
            BasePath            = $pathManager.GetCurrentPath()  # Use PathManager as source
            ServiceRegistry     = [ServiceRegistry] # Expose registry if needed
        }
        
        # 8. Validate context (fail fast if something is wrong)
        [AppBuilder]::ValidateContext($context)
        
        return $context
    }
    
    static hidden [void] ValidateContext([PSCustomObject]$context) {
        # Critical properties that must never be null
        $criticalProperties = @(
            'RepoManager',
            'Renderer',
            'Console',
            'OptionSelector',
            'PathManager',
            'LocalizationService',
            'PreferencesService'
        )
        
        $missingProperties = @()
        
        foreach ($prop in $criticalProperties) {
            $value = $context.PSObject.Properties[$prop]
            if ($null -eq $value -or $null -eq $value.Value) {
                $missingProperties += $prop
            }
        }
        
        if ($missingProperties.Count -gt 0) {
            $missing = $missingProperties -join ', '
            throw "Application context validation failed. Missing: $missing. Check AppBuilder service registration."
        }
        
        # Validate services in registry
        $criticalServices = @('PathManager', 'UserPreferencesService', 'LocalizationService', 'RepositoryManager')
        foreach ($svc in $criticalServices) {
            if ($null -eq [ServiceRegistry]::Resolve($svc)) {
                throw "Critical service missing from registry: $svc. Check import order in repo-nav.ps1"
            }
        }
    }
}

