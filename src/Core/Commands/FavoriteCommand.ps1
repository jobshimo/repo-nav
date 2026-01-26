# IMPORTANT: INavigationCommand.ps1 must be loaded BEFORE this file

class FavoriteCommand : INavigationCommand {
    [string] GetDescription() {
        return "Toggle favorite status (F)"
    }

    [bool] CanExecute([object]$keyPress, [CommandContext]$context) {
        return $keyPress.VirtualKeyCode -eq [Constants]::KEY_F
    }

    [void] Execute([object]$keyPress, [CommandContext]$context) {
        $state = $context.State
        $repos = $state.GetRepositories()
        $currentIndex = $state.GetCurrentIndex()
        
        if ($repos.Count -eq 0) { return }
        
        # Get current repository before toggle
        $currentRepo = $repos[$currentIndex]
        $repoName = $currentRepo.Name
        
        # Toggle favorite status via RepositoryManager (updates persistence)
        $repoManager = $context.RepoManager
        $repoManager.ToggleFavorite($currentRepo)
        
        # Check if we need to re-sort (only when favoritesOnTop is enabled)
        $preferencesService = $context.RepoManager.PreferencesService
        $favoritesOnTop = $preferencesService.GetPreference("display", "favoritesOnTop")
        
        if ($favoritesOnTop) {
            # Re-sort: favorites first, then alphabetically
            $sorted = $repos | Sort-Object @{Expression = {-$_.IsFavorite}}, Name
            $state.SetRepositories([System.Collections.Generic.List[RepositoryModel]]$sorted)
            
            # Find the new position of the repository after sorting
            $newIndex = 0
            for ($i = 0; $i -lt $sorted.Count; $i++) {
                if ($sorted[$i].Name -eq $repoName) {
                    $newIndex = $i
                    break
                }
            }
            $state.SetCurrentIndex($newIndex)
            $state.MarkForFullRedraw()
        } else {
            # No re-sort needed, just redraw the current line to update the star
            $state.SetCurrentIndex($currentIndex)
        }
    }
}


