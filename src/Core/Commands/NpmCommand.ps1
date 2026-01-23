# IMPORTANT: INavigationCommand.ps1 must be loaded BEFORE this file

class NpmCommand : INavigationCommand {
    [string] GetDescription() {
        return "Install npm (I) or Remove node_modules (X)"
    }

    [bool] CanExecute([System.ConsoleKeyInfo]$keyPress, [hashtable]$context) {
        $key = $keyPress.Key
        return $key -eq [System.ConsoleKey]::I -or $key -eq [System.ConsoleKey]::X
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
            if ($key -eq [System.ConsoleKey]::I) {
                # Install node_modules
                Invoke-NpmInstall -Repository $currentRepo
            }
            elseif ($key -eq [System.ConsoleKey]::X) {
                # Remove node_modules
                Invoke-NodeModulesRemove -Repository $currentRepo
            }
            
            # Reload repositories to reflect changes (e.g., node_modules presence)
            $repoManager = $context.RepoManager
            if ($null -ne $repoManager) {
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
