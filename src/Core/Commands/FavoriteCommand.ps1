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
        
        # Get updated repositories (already sorted according to user preferences)
        $updatedRepos = $repoManager.GetRepositories()
        $state.SetRepositories($updatedRepos)
        
        # Find the new index of the current repository after potential re-sorting
        $newIndex = 0
        for ($i = 0; $i -lt $updatedRepos.Count; $i++) {
            if ($updatedRepos[$i].Name -eq $repoName) {
                $newIndex = $i
                break
            }
        }
        
        # Update selection to the same repository
        $state.SetCurrentIndex($newIndex)
        
        # Mark for full redraw because list order changed
        $state.MarkForFullRedraw()
    }
}


