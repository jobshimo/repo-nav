# IMPORTANT: INavigationCommand.ps1 must be loaded BEFORE this file

class PreferencesCommand : INavigationCommand {
    [string] GetDescription() {
        return "Open preferences menu (U)"
    }

    [bool] CanExecute([System.ConsoleKeyInfo]$keyPress, [hashtable]$context) {
        return $keyPress.Key -eq [System.ConsoleKey]::U
    }

    [void] Execute([System.ConsoleKeyInfo]$keyPress, [hashtable]$context) {
        $state = $context.State
        
        # Stop the navigation loop to allow interactive menu
        $state.Stop()
        
        try {
            # Show preferences menu (may change sorting preferences) - Pass required parameters
            Show-PreferencesMenu -PreferencesService $context.RepoManager.PreferencesService -Console $context.Console -Renderer $context.Renderer -OptionSelector $context.OptionSelector
            
            # Reload repositories after preferences change
            # (sorting order may have changed)
            $repoManager = $context.RepoManager
            if ($null -ne $repoManager) {
                $repoManager.LoadRepositories($context.BasePath)
                $updatedRepos = $repoManager.GetRepositories()
                $state.SetRepositories($updatedRepos)
                
                # Reset selection to first item after preference changes
                $state.SetCurrentIndex(0)
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
