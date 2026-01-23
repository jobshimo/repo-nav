<#
.SYNOPSIS
    Git command - handles L and G keys for loading git status
    
.DESCRIPTION
    L: Loads git status for the currently selected repository
    G: Loads git status for all repositories that haven't been loaded yet
    
.NOTES
    Implements INavigationCommand interface
    Keys: L (Load current), G (Load all/Global)
    
    IMPORTANT: INavigationCommand.ps1 must be loaded BEFORE this file
#>

class GitCommand : INavigationCommand {
    # Configuration
    [string] $Mode         # "Current" or "All"
    
    # Dependencies (from context)
    # Will use context["RepoManager"]
    
    # Constructor
    GitCommand([string]$mode) {
        if ($mode -ne "Current" -and $mode -ne "All") {
            throw "Mode must be 'Current' or 'All'"
        }
        $this.Mode = $mode
    }
    
    <#
    .SYNOPSIS
        Can execute if there are repositories
    #>
    [bool] CanExecute([object]$state) {
        return $state.GetTotalCount() -gt 0
    }
    
    <#
    .SYNOPSIS
        Loads git status for current or all repositories
    #>
    [void] Execute([object]$state, [hashtable]$context) {
        $repoManager = $context["RepoManager"]
        
        if ($null -eq $repoManager) {
            throw "RepoManager not found in context"
        }
        
        if ($this.Mode -eq "Current") {
            # Load git status for selected repository only
            $selectedRepo = $state.GetSelectedRepository()
            if ($null -ne $selectedRepo) {
                $repoManager.LoadGitStatus($selectedRepo)
            }
            
            # Partial redraw (only current item + footer)
            $state.MarkForPartialRedraw()
        }
        else {
            # Load git status for all repositories
            $repoManager.LoadMissingGitStatus()
            
            # Full redraw (all items changed)
            $state.MarkForFullRedraw()
        }
    }
    
    <#
    .SYNOPSIS
        Returns command description
    #>
    [string] GetDescription() {
        if ($this.Mode -eq "Current") {
            return "Load git status (current)"
        }
        else {
            return "Load git status (all)"
        }
    }
}
