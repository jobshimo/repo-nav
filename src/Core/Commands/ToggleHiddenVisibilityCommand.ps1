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
        
        # Reload repositories to apply the new filter
        $repoManager = $context.RepoManager
        if ($null -ne $repoManager) {
            $repoManager.LoadRepositories($context.BasePath)
            $updatedRepos = $repoManager.GetRepositories()
            $state.SetRepositories($updatedRepos)
            
            # Reset selection to first item
            $state.SetCurrentIndex(0)
        }
        
        # Mark for full redraw
        $state.MarkForFullRedraw()
    }
}
