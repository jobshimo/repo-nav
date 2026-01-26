# IMPORTANT: INavigationCommand.ps1 must be loaded BEFORE this file

class RepositoryCommand : INavigationCommand {
    [string] GetDescription() {
        return "Open repository/container (ENTER)"
    }

    [bool] CanExecute([object]$keyPress, [CommandContext]$context) {
        return $keyPress.VirtualKeyCode -eq [Constants]::KEY_ENTER
    }

    [void] Execute([object]$keyPress, [CommandContext]$context) {
        $state = $context.State
        $repos = $state.GetRepositories()
        $currentIndex = $state.GetCurrentIndex()
        
        if ($repos.Count -eq 0) { return }
        
        $selectedRepo = $repos[$currentIndex]
        
        # Check if this is a container folder
        if ($selectedRepo.IsContainer) {
            # Enter the container - load its repositories
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
            
            return
        }
        
        # Regular repository - open it
        # Set exit state to "OpenRepository"
        $state.SetExitState("OpenRepository")
        
        # Stop the navigation loop
        $state.Stop()
    }
}


