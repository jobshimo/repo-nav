# IMPORTANT: INavigationCommand.ps1 must be loaded BEFORE this file

class RepositoryCommand : INavigationCommand {
    [string] GetDescription() {
        return "Open repository/container (ENTER)"
    }

    [bool] CanExecute([object]$keyPress, [hashtable]$context) {
        return $keyPress.VirtualKeyCode -eq [Constants]::KEY_ENTER
    }

    [void] Execute([object]$keyPress, [hashtable]$context) {
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
            
            $this.CheckAutoLoad($context, $newRepos)
            
            return
        }
        
        # Regular repository - open it
        # Set exit state to "OpenRepository"
        $state.SetExitState("OpenRepository")
        
        # Stop the navigation loop
        $state.Stop()
    }

    [void] CheckAutoLoad([hashtable]$context, [array]$repos) {
         $prefsService = $context.PreferencesService
         if ($null -eq $prefsService) { return }

         $mode = $prefsService.GetPreference("git", "autoLoadGitStatusMode")
         if (-not $mode) { $mode = "None" }
         
         if ($mode -ne "None") {
             $toLoad = @()
             $msg = ""
             if ($mode -eq "Favorites") {
                 $toLoad = $repos | Where-Object { $_.IsFavorite }
                 $msg = "favorites"
             } elseif ($mode -eq "All") {
                 $toLoad = $repos
                 $msg = "all"
             }
             
             if ($toLoad.Count -gt 0) {
                  $progressIndicator = [ProgressIndicator]::new($context.Console)
                  $progressCallback = {
                     param([int]$c, [int]$t)
                     $progressIndicator.RenderProgressBar("Loading git status ($msg)", $c, $t)
                  }
                  $context.RepoManager.LoadGitStatusForRepos($toLoad, $progressCallback)
                  $progressIndicator.CompleteProgressBar()
             }
         }
    }
}


