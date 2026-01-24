# IMPORTANT: INavigationCommand.ps1 must be loaded BEFORE this file

class NpmCommand : INavigationCommand {
    [string] GetDescription() {
        return "Install npm (I) or Remove node_modules (X)"
    }

    [bool] CanExecute([object]$keyPress, [hashtable]$context) {
        $key = $keyPress.VirtualKeyCode
        return $key -eq [Constants]::KEY_I -or $key -eq [Constants]::KEY_X
    }

    [void] Execute([object]$keyPress, [hashtable]$context) {
        $state = $context.State
        $repos = $state.GetRepositories()
        $currentIndex = $state.GetCurrentIndex()
        
        if ($repos.Count -eq 0) { return }
        
        $currentRepo = $repos[$currentIndex]
        $key = $keyPress.VirtualKeyCode
        
        # Stop the navigation loop to allow interactive input
        $state.Stop()
        
        try {
            if ($key -eq [Constants]::KEY_I) {
                # Install node_modules
                Invoke-NpmInstall -Repository $currentRepo -LocalizationService $context.LocalizationService
            }
            elseif ($key -eq [Constants]::KEY_X) {
                # Remove node_modules - Pass required parameters
                Invoke-NodeModulesRemove -RepoManager $context.RepoManager -Repository $currentRepo -Console $context.Console -Renderer $context.Renderer -LocalizationService $context.LocalizationService -OptionSelector $context.OptionSelector
            }
            
            # Reload repositories to reflect changes (e.g., node_modules presence)
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


