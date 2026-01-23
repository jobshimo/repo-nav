# IMPORTANT: INavigationCommand.ps1 must be loaded BEFORE this file

class FavoriteCommand : INavigationCommand {
    [string] GetDescription() {
        return "Toggle favorite status (F)"
    }

    [bool] CanExecute([System.ConsoleKeyInfo]$keyPress, [hashtable]$context) {
        return $keyPress.Key -eq [System.ConsoleKey]::F
    }

    [void] Execute([System.ConsoleKeyInfo]$keyPress, [hashtable]$context) {
        $state = $context.State
        $repos = $state.GetRepositories()
        $currentIndex = $state.GetCurrentIndex()
        
        if ($repos.Count -eq 0) { return }
        
        # Get current repository before toggle
        $currentRepo = $repos[$currentIndex]
        $repoName = $currentRepo.Name
        
        # Toggle favorite status
        $repos[$currentIndex].IsFavorite = -not $repos[$currentIndex].IsFavorite
        
        # Re-sort the list (favorites first)
        $sortedRepos = $repos | Sort-Object -Property @(
            @{Expression = {-not $_.IsFavorite}; Ascending = $true}
            @{Expression = {$_.Name}; Ascending = $true}
        )
        
        # Update state with sorted repositories
        $state.SetRepositories($sortedRepos)
        
        # Find the new index of the current repository after sorting
        $newIndex = 0
        for ($i = 0; $i -lt $sortedRepos.Count; $i++) {
            if ($sortedRepos[$i].Name -eq $repoName) {
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
