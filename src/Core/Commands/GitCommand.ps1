# IMPORTANT: INavigationCommand.ps1 must be loaded BEFORE this file

class GitCommand : INavigationCommand {
    [string] GetDescription() {
        return "Load git status - L (current) / G (all)"
    }

    [bool] CanExecute([object]$keyPress, [hashtable]$context) {
        $key = $keyPress.VirtualKeyCode
        return $key -eq [Constants]::KEY_L -or $key -eq [Constants]::KEY_G
    }

    [void] Execute([object]$keyPress, [hashtable]$context) {
        $state = $context.State
        $repos = $state.GetRepositories()
        $currentIndex = $state.GetCurrentIndex()
        $key = $keyPress.VirtualKeyCode
        
        $repoManager = $context.RepoManager
        if ($null -eq $repoManager) {
            throw "RepoManager not found in context"
        }
        
        if ($key -eq [Constants]::KEY_L) {
            # Load git status for current repository
            if ($repos.Count -gt 0) {
                $currentRepo = $repos[$currentIndex]
                $repoManager.LoadGitStatus($currentRepo)
                
                # Mark for full redraw to update footer
                $state.MarkForFullRedraw()
            }
        }
        elseif ($key -eq [Constants]::KEY_G) {
            # Load git status for all repositories
            $repoManager.LoadMissingGitStatus()
            
            # Mark for full redraw
            $state.MarkForFullRedraw()
        }
    }
}


