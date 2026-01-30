<#
.SYNOPSIS
    Main navigation loop - Refactored with Command Pattern
    
.DESCRIPTION
    Orchestrates the navigation UI using NavigationState, CommandFactory, 
    InputHandler, and RenderOrchestrator. Reduced from 409 lines to ~100 lines.
#>

function Start-NavigationLoop {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Context
    )
    
    # Unpack context for local usage
    $RepoManager = $Context.RepoManager
    $Renderer = $Context.Renderer
    $Console = $Context.Console
    $Logger = $Context.Logger
    $ColorSelector = $Context.ColorSelector
    $OptionSelector = $Context.OptionSelector
    $LocalizationService = $Context.LocalizationService
    $PreferencesService = $Context.PreferencesService
    $HiddenReposService = $Context.HiddenReposService
    $BasePath = $Context.BasePath
    
    # Load repositories
    # Load repositories
    if (-not [string]::IsNullOrWhiteSpace($BasePath)) {
        try {
            $RepoManager.LoadRepositories($BasePath)
        } catch {
            $Renderer.RenderError("Failed to load repositories from: $BasePath")
            Start-Sleep -Seconds 1
        }
    }
    
    $repos = $RepoManager.GetRepositories()
    if ($repos.Count -eq 0) {
        $OnboardingService = $Context.OnboardingService
        $newPath = $OnboardingService.HandleEmptyState($BasePath)
        
        if ($newPath) {
            $Context.BasePath = $newPath
            Start-NavigationLoop -Context $Context
        }
        return
    }

    
    try {
        $Console.HideCursor()
        
        # Create state with base path for hierarchical navigation
        $state = [NavigationState]::new($repos, $BasePath)
        
        $cursorStartLine = [Constants]::CursorStartLine
        $renderOrchestrator = [RenderOrchestrator]::new($Renderer, $Console, $cursorStartLine, $HiddenReposService)
        
        $progressIndicator = [ProgressIndicator]::new($Console)
        
        # Ensure this path is in preferences (only if valid)
        if (-not [string]::IsNullOrWhiteSpace($BasePath)) {
            $PreferencesService.EnsurePathInPreferences($BasePath)
        }
        
        $autoLoadFavorites = $PreferencesService.GetPreference("git", "autoLoadFavoritesStatus")
        if ($null -ne $autoLoadFavorites) {
             # Legacy cleanup if needed, though PerformAutoLoadGitStatus handles new pref
        }

        # Perform Auto Load using centralized logic
        $RepoManager.PerformAutoLoadGitStatus($repos, $Console)
        
        # Initialize CommandFactory and InputHandler
        $factory = [CommandFactory]::new()
        $inputHandler = [InputHandler]::new($factory)
        
        # Create CommandContext for commands (Strongly Typed)
        $commandContext = [CommandContext]::new()
        $commandContext.State = $state
        $commandContext.RepoManager = $RepoManager
        $commandContext.Renderer = $Renderer
        $commandContext.Console = $Console
        $commandContext.ColorSelector = $ColorSelector
        $commandContext.OptionSelector = $OptionSelector
        $commandContext.LocalizationService = $LocalizationService
        $commandContext.PreferencesService = $PreferencesService
        $commandContext.HiddenReposService = $HiddenReposService
        $commandContext.BasePath = $BasePath
        
        # Initial full render and layout calculation
        $renderOrchestrator.Initialize($state)
        
        # Main input loop - Simplified using Command Pattern
        while (-not $state.ShouldExit()) {
            # Ensure cursor is hidden at the start of each loop iteration
            $Console.HideCursor()
            
            $keyPress = $Console.ReadKey()
            
            # Delegate input handling to InputHandler
            $handled = $inputHandler.HandleInput($keyPress, $commandContext)
            
            if (-not $handled) {
                # Key not handled by any command - ignore silently
                continue
            }
            
            # Handle rendering based on state flags
            $renderOrchestrator.RenderIfNeeded($state)
        }
        
        # Handle exit state
        $exitState = $state.GetExitState()
        if ($exitState -eq [ExitState]::OpenRepository) {
            $repos = $state.GetRepositories()
            $currentIndex = $state.GetCurrentIndex()
            if ($currentIndex -lt $repos.Count) {
                $selectedRepo = $repos[$currentIndex]
                $Console.ClearScreen()
                $Renderer.RenderSuccess("Opening: $($selectedRepo.Name)")
                Set-Location $selectedRepo.FullPath
            }
        }
        elseif ($exitState -eq [ExitState]::Restart) {
            # Restart loop with updated context using PathManager
            $pathManager = $Context.PathManager
            $pathManager.Refresh()
            $Context.BasePath = $pathManager.GetCurrentPath()
            Start-NavigationLoop -Context $Context
            return
        }
        elseif ($exitState -eq [ExitState]::Cancelled) {
            $Console.ClearScreen()
            $Renderer.RenderWarning("Navigation cancelled.")
        }
    }
    catch {
        $Console.ShowCursor() # Ensure cursor is visible on error
        $Logger.LogError($_)
        throw # Re-throw to be caught by the main script error handler if needed, or just let it crash after logging
    }
    finally {
        $Console.ShowCursor()
    }
}
