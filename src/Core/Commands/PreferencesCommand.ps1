# IMPORTANT: INavigationCommand.ps1 must be loaded BEFORE this file

class PreferencesCommand : INavigationCommand {
    [string] GetDescription() {
        return "Open preferences menu (U)"
    }

    [bool] CanExecute([object]$keyPress, [CommandContext]$context) {
        return $keyPress.VirtualKeyCode -eq [Constants]::KEY_U
    }

    [void] Execute([object]$keyPress, [CommandContext]$context) {
        $state = $context.State
        
        # Stop the navigation loop to allow interactive menu
        $state.Stop()
        
        try {
            # Instantiate and show preferences menu controller
            $controller = [PreferencesMenuController]::new($context)
            $controller.Show()
            
            # Use PathManager as Single Source of Truth (with null guard)
            $pathManager = $context.PathManager
            if ($null -ne $pathManager) {
                $pathManager.Refresh()  # Sync from file after preferences changes
                $newDefaultPath = $pathManager.GetCurrentPath()
            } else {
                # Fallback to direct preferences read if PathManager not available
                $prefs = $context.PreferencesService.LoadPreferences()
                $newDefaultPath = $prefs.Repository.DefaultPath
            }
            
            # Check if we still have a valid path
            if ([string]::IsNullOrWhiteSpace($newDefaultPath)) {
                # No valid path - restart to trigger onboarding
                $state.RequestExit([ExitState]::Restart)
                $context.BasePath = ""
                return
            }
            
            # Update context with new path
            $context.BasePath = $newDefaultPath
            
            # Reload repositories with the updated path
            $repoManager = $context.RepoManager
            if ($null -ne $repoManager) {
                $repoManager.LoadRepositories($newDefaultPath)
                $updatedRepos = $repoManager.GetRepositories()
                $state.SetRepositories($updatedRepos)
                
                # Update state's base path reference
                $state.SetBasePath($newDefaultPath)
                
                # Reset selection to first item after preference changes
                $state.SetCurrentIndex(0)
            }
        }
        finally {
            # ALWAYS mark for full redraw and resume, even if error occurred
            $state.MarkForFullRedraw()
            $state.Resume()
        }
    }
}
