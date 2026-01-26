# IMPORTANT: INavigationCommand.ps1 must be loaded BEFORE this file

class AliasCommand : INavigationCommand {
    [string] GetDescription() {
        return "Edit (E) or Remove (R) alias"
    }

    [bool] CanExecute([object]$keyPress, [CommandContext]$context) {
        $key = $keyPress.VirtualKeyCode
        return $key -eq [Constants]::KEY_E -or $key -eq [Constants]::KEY_R
    }

    [void] Execute([object]$keyPress, [CommandContext]$context) {
        $state = $context.State
        $repos = $state.GetRepositories()
        $currentIndex = $state.GetCurrentIndex()
        
        if ($repos.Count -eq 0) { return }
        
        $currentRepo = $repos[$currentIndex]
        $key = $keyPress.VirtualKeyCode
        
        # Create View
        $view = [AliasView]::new(
            $context.Console, 
            $context.LocalizationService, 
            $context.Renderer,
            $context.ColorSelector,
            $context.OptionSelector
        )
        
        # Stop loop
        $state.Stop()
        
        try {
            if ($key -eq [Constants]::KEY_E) {
                $this.InvokeAliasEdit($context, $currentRepo, $view)
            }
            elseif ($key -eq [Constants]::KEY_R) {
                $this.InvokeAliasRemove($context, $currentRepo, $view)
            }
            
            # Refresh Logic
            $repoManager = $context.RepoManager
            if ($null -ne $repoManager) {
                $repoManager.LoadRepositories($context.BasePath)
                $updatedRepos = $repoManager.GetRepositories()
                $state.SetRepositories($updatedRepos)
                
                # Restore selection
                $newIndex = 0
                for ($i = 0; $i -lt $updatedRepos.Count; $i++) {
                    if ($updatedRepos[$i].Path -eq $currentRepo.Path) {
                        $newIndex = $i
                        break
                    }
                }
                $state.SetCurrentIndex($newIndex)
            }
            
            $state.MarkForFullRedraw()
        }
        finally {
            $state.Resume()
        }
    }

    hidden [void] InvokeAliasEdit($context, [RepositoryModel]$repo, [AliasView]$view) {
        $repoManager = $context.RepoManager
        
        # 1. View: Get Data
        $aliasInfo = $view.GetAliasDetails($repo)
        
        if ($null -eq $aliasInfo) { return }
        
        # 2. Service: Save
        $result = $repoManager.SetAlias($repo, $aliasInfo)
        
        # 3. View: Show Result
        $view.ShowSaveResult($result, $aliasInfo)
    }

    hidden [void] InvokeAliasRemove($context, [RepositoryModel]$repo, [AliasView]$view) {
        $repoManager = $context.RepoManager
        
        # 1. View: Confirm
        $confirm = $view.ConfirmRemove($repo)
        if (-not $confirm) { return }
        
        # 2. Service: Delete
        $result = $repoManager.RemoveAlias($repo)
        
        # 3. View: Show Result
        $view.ShowRemoveResult($result)
    }
}
