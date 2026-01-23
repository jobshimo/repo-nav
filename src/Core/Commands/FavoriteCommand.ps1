<#
.SYNOPSIS
    Favorite command - handles F key to toggle favorite status
    
.DESCRIPTION
    Toggles the favorite status of the selected repository.
    After toggling, the list is re-sorted (favorites first) and
    the selection is maintained on the same repository.
    
.NOTES
    Implements INavigationCommand interface
    Key: F
#>

. "$PSScriptRoot\INavigationCommand.ps1"

class FavoriteCommand : INavigationCommand {
    # No dependencies needed - uses context
    
    # Constructor
    FavoriteCommand() {
    }
    
    <#
    .SYNOPSIS
        Can execute if there's a selected repository
    #>
    [bool] CanExecute([object]$state) {
        $repo = $state.GetSelectedRepository()
        return $null -ne $repo
    }
    
    <#
    .SYNOPSIS
        Toggles favorite status and updates display
    #>
    [void] Execute([object]$state, [hashtable]$context) {
        $repoManager = $context["RepoManager"]
        
        if ($null -eq $repoManager) {
            throw "RepoManager not found in context"
        }
        
        # Get current repository name (to find it after re-sort)
        $selectedRepo = $state.GetSelectedRepository()
        if ($null -eq $selectedRepo) {
            return
        }
        
        $selectedRepoName = $selectedRepo.Name
        
        # Toggle favorite status
        $repoManager.ToggleFavorite($selectedRepo)
        
        # Refresh repositories list (will be re-sorted)
        $repos = $repoManager.GetRepositories()
        $state.UpdateRepositories($repos)
        
        # Find the new index of the repository (it may have moved)
        $newIndex = $state.FindRepositoryIndex($selectedRepoName)
        $state.SelectIndex($newIndex)
        
        # Full redraw needed (list was re-sorted)
        $state.MarkForFullRedraw()
    }
    
    <#
    .SYNOPSIS
        Returns command description
    #>
    [string] GetDescription() {
        return "Toggle favorite"
    }
}
