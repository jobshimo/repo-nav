# IMPORTANT: INavigationCommand.ps1 must be loaded BEFORE this file

class NavigationCommand : INavigationCommand {
    [string] GetDescription() {
        return "Navigate (UP/DOWN/LEFT/RIGHT arrows)"
    }

    [bool] CanExecute([object]$keyPress, [hashtable]$context) {
        $key = $keyPress.VirtualKeyCode
        return $key -eq [Constants]::KEY_UP_ARROW -or 
               $key -eq [Constants]::KEY_DOWN_ARROW -or
               $key -eq [Constants]::KEY_LEFT_ARROW -or
               $key -eq [Constants]::KEY_RIGHT_ARROW
    }

    [void] Execute([object]$keyPress, [hashtable]$context) {
        $state = $context.State
        $repos = $state.GetRepositories()
        $key = $keyPress.VirtualKeyCode
        
        # Handle LEFT arrow - Go back in container hierarchy
        if ($key -eq [Constants]::KEY_LEFT_ARROW) {
            if ($state.CanGoBack()) {
                $state.GoBack()
            }
            return
        }
        
        # Handle RIGHT arrow - Enter container (only if it's a container)
        if ($key -eq [Constants]::KEY_RIGHT_ARROW) {
            if ($repos.Count -eq 0) { return }
            
            $currentIndex = $state.GetCurrentIndex()
            $selectedRepo = $repos[$currentIndex]
            
            # Only enter if it's a container
            if ($selectedRepo.IsContainer) {
                $repoManager = $context.RepoManager
                $containerPath = $selectedRepo.FullPath
                $parentPath = $state.GetCurrentPath()
                
                # Load repositories from the container
                $repoManager.LoadContainerRepositories($containerPath, $parentPath)
                $newRepos = $repoManager.GetRepositories()
                
                # Enter container in navigation state
                $state.EnterContainer($containerPath, $newRepos)
                
                # Check auto load using centralized method
                $context.RepoManager.PerformAutoLoadGitStatus($newRepos, $context.Console)
            }
            return
        }
        
        if ($repos.Count -eq 0) { return }
        
        $currentIndex = $state.GetCurrentIndex()
        
        # Calculate new index
        if ($key -eq [Constants]::KEY_UP_ARROW) {
            if ($currentIndex -gt 0) {
                $state.SetCurrentIndex($currentIndex - 1)
            }
            else {
                $state.SetCurrentIndex($repos.Count - 1)
            }
        }
        elseif ($key -eq [Constants]::KEY_DOWN_ARROW) {
            if ($currentIndex -lt ($repos.Count - 1)) {
                $state.SetCurrentIndex($currentIndex + 1)
            }
            else {
                $state.SetCurrentIndex(0)
            }
        }
        
        # Selection changed flag is automatically set by SetCurrentIndex()
    }
}


