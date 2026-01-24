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
        
        # Get dependencies from context
        $console = $context.Console
        if ($null -eq $console) {
            $console = [ConsoleHelper]::new()
        }
        
        # Create progress indicator
        $progressIndicator = [ProgressIndicator]::new($console)
        
        if ($key -eq [Constants]::KEY_L) {
            # Load git status for current repository (single operation - animated dots)
            if ($repos.Count -gt 0) {
                $currentRepo = $repos[$currentIndex]
                
                # Show animated dots during git fetch (synchronous animation + action)
                $progressIndicator.ShowLoadingDots("Loading git status", {
                    $repoManager.LoadGitStatus($currentRepo)
                })
                
                # Only trigger selection change (partial redraw - just current item + footer)
                # This avoids full screen redraw and eliminates flicker
                $state.SetCurrentIndex($currentIndex)
            }
        }
        elseif ($key -eq [Constants]::KEY_G) {
            # Load git status for all repositories (progress bar)
            
            # Define progress callback (DIP - GitCommand doesn't know about ProgressIndicator internals)
            $progressCallback = {
                param([int]$current, [int]$total)
                $progressIndicator.RenderProgressBar("Loading git status", $current, $total)
            }
            
            try {
                $repoManager.LoadMissingGitStatus($progressCallback)
            }
            finally {
                $progressIndicator.CompleteProgressBar()
            }
            
            # Mark for full redraw
            $state.MarkForFullRedraw()
        }
    }
}


