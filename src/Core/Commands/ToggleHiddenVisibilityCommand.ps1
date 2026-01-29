# IMPORTANT: INavigationCommand.ps1 must be loaded BEFORE this file

class ToggleHiddenVisibilityCommand : INavigationCommand {
    [string] GetDescription() {
        return "Toggle hidden repos visibility (V)"
    }

    [bool] CanExecute([object]$keyPress, [CommandContext]$context) {
        return $keyPress.VirtualKeyCode -eq [Constants]::KEY_V
    }

    [void] Execute([object]$keyPress, [CommandContext]$context) {
        $state = $context.State
        
        # Get HiddenReposService from context
        $hiddenService = $context.HiddenReposService
        if ($null -eq $hiddenService) { return }
        
        # Toggle visibility state
        $hiddenService.ToggleShowHidden()
        
        $currentIndex = $state.GetCurrentIndex()
        $currentRepo = if ($currentIndex -ge 0 -and $currentIndex -lt $state.GetRepositories().Count) { $state.GetRepositories()[$currentIndex] } else { $null }
        
        # Reload repositories to apply the new filter (Now fast via Cache)
        $repoManager = $context.RepoManager
        if ($null -ne $repoManager) {
            $repoManager.LoadRepositories()
            $updatedRepos = $repoManager.GetRepositories()
            $state.SetRepositories($updatedRepos)
            
            # Try to restore selection
            $newIndex = 0
            if ($null -ne $currentRepo) {
                for ($i = 0; $i -lt $updatedRepos.Count; $i++) {
                    if ($updatedRepos[$i].FullPath -eq $currentRepo.FullPath) {
                        $newIndex = $i
                        break
                    }
                }
            }
            
            $state.SetCurrentIndex($newIndex)
        }
        
        # Mark for list redraw (Partial update, no flickering)
        $state.MarkForListRedraw()
    }
}
