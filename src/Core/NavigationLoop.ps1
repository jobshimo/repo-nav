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
        $RepoManager,
        
        [Parameter(Mandatory = $true)]
        $Renderer,
        
        [Parameter(Mandatory = $true)]
        $Console,
        
        [Parameter(Mandatory = $true)]
        $ColorSelector,
        
        [Parameter(Mandatory = $true)]
        $OptionSelector,
        
        [Parameter(Mandatory = $true)]
        [string]$BasePath
    )
    
    # Load repositories
    $RepoManager.LoadRepositories($BasePath)
    
    $repos = $RepoManager.GetRepositories()
    if ($repos.Count -eq 0) {
        $Renderer.RenderError("No repositories found in this folder.")
        return
    }
    
    try {
        $Console.HideCursor()
        
        $state = [NavigationState]::new($repos)
        
        $cursorStartLine = [Constants]::CursorStartLine
        $renderOrchestrator = [RenderOrchestrator]::new($Renderer, $Console, $cursorStartLine)
        
        $progressIndicatorPath = Join-Path $PSScriptRoot "..\UI\ProgressIndicator.ps1"
        . $progressIndicatorPath
        $progressIndicator = [ProgressIndicator]::new($Console)
        
        $preferencesService = [UserPreferencesService]::new()
        $autoLoadFavorites = $preferencesService.GetPreference("git", "autoLoadFavoritesStatus")
        
        if ($autoLoadFavorites) {
            $favorites = $repos | Where-Object { $_.IsFavorite }
            if ($favorites.Count -gt 0) {
                $total = $favorites.Count
                $current = 0
                
                foreach ($fav in $favorites) {
                    $current++
                    $progressIndicator.RenderProgressBar("Loading git status (favorites)", $current, $total)
                    $RepoManager.LoadGitStatus($fav)
                }
                
                $progressIndicator.CompleteProgressBar()
            }
        }
        
        . "$PSScriptRoot\Commands\INavigationCommand.ps1"
        . "$PSScriptRoot\Commands\ExitCommand.ps1"
        . "$PSScriptRoot\Commands\NavigationCommand.ps1"
        . "$PSScriptRoot\Commands\RepositoryCommand.ps1"
        . "$PSScriptRoot\Commands\GitCommand.ps1"
        . "$PSScriptRoot\Commands\FavoriteCommand.ps1"
        . "$PSScriptRoot\Commands\AliasCommand.ps1"
        . "$PSScriptRoot\Commands\NpmCommand.ps1"
        . "$PSScriptRoot\Commands\RepositoryManagementCommand.ps1"
        . "$PSScriptRoot\Commands\PreferencesCommand.ps1"
        . "$PSScriptRoot\CommandFactory.ps1"
        . "$PSScriptRoot\InputHandler.ps1"
        
        # Initialize CommandFactory and InputHandler
        $factory = [CommandFactory]::new()
        $inputHandler = [InputHandler]::new($factory)
        
        # Create context hashtable for commands
        $context = @{
            State = $state
            RepoManager = $RepoManager
            Renderer = $Renderer
            Console = $Console
            ColorSelector = $ColorSelector
            OptionSelector = $OptionSelector
            BasePath = $BasePath
        }
        
        # Initial full render
        $Console.ClearScreen()
        $Renderer.RenderHeader("REPOSITORY NAVIGATOR")
        $Renderer.RenderMenu()
        
        $repos = $state.GetRepositories()
        $currentIndex = $state.GetCurrentIndex()
        
        for ($i = 0; $i -lt $repos.Count; $i++) {
            $Renderer.RenderRepositoryItem($repos[$i], ($i -eq $currentIndex))
        }
        
        Write-Host ""
        $totalRepos = $repos.Count
        $loadedRepos = $repos | Where-Object { $_.HasGitStatusLoaded() } | Measure-Object | Select-Object -ExpandProperty Count
        $Renderer.RenderGitStatusFooter($repos[$currentIndex], $totalRepos, $loadedRepos)
        
        # Main input loop - Simplified using Command Pattern
        while (-not $state.ShouldExit()) {
            $keyPress = $Console.ReadKey()
            
            # Delegate input handling to InputHandler
            $handled = $inputHandler.HandleInput($keyPress, $context)
            
            if (-not $handled) {
                # Key not handled by any command - ignore silently
                continue
            }
            
            # Handle rendering based on state flags
            if ($state.NeedsFullRedraw()) {
                # Full redraw requested
                $repos = $state.GetRepositories()
                $currentIndex = $state.GetCurrentIndex()
                
                $Console.ClearScreen()
                $Renderer.RenderHeader("REPOSITORY NAVIGATOR")
                $Renderer.RenderMenu()
                
                for ($i = 0; $i -lt $repos.Count; $i++) {
                    $Renderer.RenderRepositoryItem($repos[$i], ($i -eq $currentIndex))
                }
                
                Write-Host ""
                $totalRepos = $repos.Count
                $loadedRepos = $repos | Where-Object { $_.HasGitStatusLoaded() } | Measure-Object | Select-Object -ExpandProperty Count
                $Renderer.RenderGitStatusFooter($repos[$currentIndex], $totalRepos, $loadedRepos)
                $Console.HideCursor()
                
                $state.ClearFullRedrawFlag()
            }
            elseif ($state.HasSelectionChanged()) {
                # Partial redraw - only update changed items
                $renderOrchestrator.RenderPartial($state)
                
                $state.ClearSelectionChangedFlag()
            }
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
