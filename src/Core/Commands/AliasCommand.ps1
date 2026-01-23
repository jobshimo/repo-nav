# IMPORTANT: INavigationCommand.ps1 must be loaded BEFORE this file

class AliasCommand : INavigationCommand {
    [string] GetDescription() {
        return "Edit (E) or Remove (R) alias"
    }

    [bool] CanExecute([System.ConsoleKeyInfo]$keyPress, [hashtable]$context) {
        $key = $keyPress.Key
        return $key -eq [System.ConsoleKey]::E -or $key -eq [System.ConsoleKey]::R
    }

    [void] Execute([System.ConsoleKeyInfo]$keyPress, [hashtable]$context) {
        $state = $context.State
        $repos = $state.GetRepositories()
        $currentIndex = $state.GetCurrentIndex()
        
        if ($repos.Count -eq 0) { return }
        
        $currentRepo = $repos[$currentIndex]
        $key = $keyPress.Key
        
        # Stop the navigation loop to allow interactive input
        $state.Stop()
        
        try {
            if ($key -eq [System.ConsoleKey]::E) {
                # Edit alias - Pass required parameters
                Invoke-AliasEdit -RepoManager $context.RepoManager -Repository $currentRepo -ColorSelector $context.ColorSelector
            }
            elseif ($key -eq [System.ConsoleKey]::R) {
                # Remove alias - Pass required parameters
                Invoke-AliasRemove -RepoManager $context.RepoManager -Repository $currentRepo
            }
            
            # Reload repositories to reflect alias changes
            $repoManager = $context.RepoManager
            if ($null -ne $repoManager) {
                $repoManager.LoadRepositories($context.BasePath)
                $updatedRepos = $repoManager.GetRepositories()
                $state.SetRepositories($updatedRepos)
                
                # Try to maintain selection on the same repository
                $newIndex = 0
                for ($i = 0; $i -lt $updatedRepos.Count; $i++) {
                    if ($updatedRepos[$i].Path -eq $currentRepo.Path) {
                        $newIndex = $i
                        break
                    }
                }
                $state.SetCurrentIndex($newIndex)
            }
            
            # Mark for full redraw
            $state.MarkForFullRedraw()
        }
        finally {
            # Resume navigation loop
            $state.Resume()
        }
    }
}
