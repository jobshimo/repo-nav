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
    $ColorSelector = $Context.ColorSelector
    $OptionSelector = $Context.OptionSelector
    $LocalizationService = $Context.LocalizationService
    $PreferencesService = $Context.PreferencesService
    $BasePath = $Context.BasePath
    
    # Load repositories
    $RepoManager.LoadRepositories($BasePath)
    
    $repos = $RepoManager.GetRepositories()
    if ($repos.Count -eq 0) {
        $Renderer.RenderError("No repositories found in this folder.")
        return
    }
    
    try {
        $Console.HideCursor()
        
        # Create state with base path for hierarchical navigation
        $state = [NavigationState]::new($repos, $BasePath)
        
        $cursorStartLine = [Constants]::CursorStartLine
        $renderOrchestrator = [RenderOrchestrator]::new($Renderer, $Console, $cursorStartLine)
        
        $progressIndicator = [ProgressIndicator]::new($Console)
        
        $autoLoadFavorites = $PreferencesService.GetPreference("git", "autoLoadFavoritesStatus")
        
        if ($autoLoadFavorites) {
            $favorites = $repos | Where-Object { $_.IsFavorite }
            if ($favorites.Count -gt 0) {
                $progressCallback = {
                    param([int]$current, [int]$total)
                    $progressIndicator.RenderProgressBar("Loading git status (favorites)", $current, $total)
                }
                
                $RepoManager.LoadGitStatusForRepos($favorites, $progressCallback)
                $progressIndicator.CompleteProgressBar()
            }
        }
        
        # Initialize CommandFactory and InputHandler
        $factory = [CommandFactory]::new()
        $inputHandler = [InputHandler]::new($factory)
        
        # Create context hashtable for commands
        $commandContext = @{
            State               = $state
            RepoManager         = $RepoManager
            Renderer            = $Renderer
            Console             = $Console
            ColorSelector       = $ColorSelector
            OptionSelector      = $OptionSelector
            LocalizationService = $LocalizationService
            BasePath            = $BasePath
        }
        
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
        if ($exitState -eq "OpenRepository") {
            $repos = $state.GetRepositories()
            $currentIndex = $state.GetCurrentIndex()
            if ($currentIndex -lt $repos.Count) {
                $selectedRepo = $repos[$currentIndex]
                $Console.ClearScreen()
                $Renderer.RenderSuccess("Opening: $($selectedRepo.Name)")
                Set-Location $selectedRepo.FullPath
            }
        }
        elseif ($exitState -eq "Cancelled") {
            $Console.ClearScreen()
            $Renderer.RenderWarning("Navigation cancelled.")
        }
    }
    finally {
        $Console.ShowCursor()
    }
}
