# IMPORTANT: INavigationCommand.ps1 must be loaded BEFORE this file

class FavoriteCommand : INavigationCommand {
    [string] GetDescription() {
        return "Toggle favorite status (F)"
    }

    [bool] CanExecute([object]$keyPress, [hashtable]$context) {
        return $keyPress.VirtualKeyCode -eq [Constants]::KEY_F
    }

    [void] Execute([object]$keyPress, [hashtable]$context) {
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
        
        # Since ToggleFavorite no longer re-sorts, the repository stays in the same position
        # We only need to trigger a selection change redraw (just the current line)
        $state.SetCurrentIndex($currentIndex)
    }
}


