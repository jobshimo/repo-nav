# IMPORTANT: INavigationCommand.ps1 must be loaded BEFORE this file

class RepositoryManagementCommand : INavigationCommand {
    [string] GetDescription() {
        return "Clone (C) or Delete (DELETE) repository"
    }

    [bool] CanExecute([object]$keyPress, [hashtable]$context) {
        $key = $keyPress.VirtualKeyCode
        return $key -eq [Constants]::KEY_C -or $key -eq [Constants]::KEY_DELETE
    }

    [void] Execute([object]$keyPress, [hashtable]$context) {
        $state = $context.State
        $repos = $state.GetRepositories()
        $currentIndex = $state.GetCurrentIndex()
        $key = $keyPress.VirtualKeyCode
        
        # Stop the navigation loop to allow interactive input
        $state.Stop()
        
        try {
            if ($key -eq [Constants]::KEY_C) {
                # Clone repository - Pass required parameters
                Invoke-RepositoryClone -RepoManager $context.RepoManager -BasePath $context.BasePath -Console $context.Console -LocalizationService $context.LocalizationService
            }
            elseif ($key -eq [Constants]::KEY_DELETE) {
                # Delete repository (CRITICAL: requires confirmation) - Pass required parameters
                if ($repos.Count -gt 0) {
                    $currentRepo = $repos[$currentIndex]
                    Invoke-RepositoryDelete -RepoManager $context.RepoManager -Repository $currentRepo -Console $context.Console -LocalizationService $context.LocalizationService -OptionSelector $context.OptionSelector
                }
            }
            
            # Reload repositories after clone/delete
            $repoManager = $context.RepoManager
            if ($null -ne $repoManager) {
                $repoManager.LoadRepositories($context.BasePath)
                $updatedRepos = $repoManager.GetRepositories()
                $state.SetRepositories($updatedRepos)
                
                # Adjust selection after deletion or addition
                if ($key -eq [Constants]::KEY_DELETE) {
                    # If we deleted the last item, move selection up
                    if ($currentIndex -ge $updatedRepos.Count -and $updatedRepos.Count -gt 0) {
                        $state.SetCurrentIndex($updatedRepos.Count - 1)
                    }
                    elseif ($updatedRepos.Count -eq 0) {
                        $state.SetCurrentIndex(0)
                    }
                }
                elseif ($key -eq [Constants]::KEY_C) {
                    # After clone, try to select the newly added repository (last one)
                    if ($updatedRepos.Count -gt 0) {
                        $state.SetCurrentIndex($updatedRepos.Count - 1)
                    }
                }
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


