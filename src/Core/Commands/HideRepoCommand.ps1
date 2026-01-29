# IMPORTANT: INavigationCommand.ps1 must be loaded BEFORE this file

class HideRepoCommand : INavigationCommand {
    [string] GetDescription() {
        return "Hide repository from list (H)"
    }

    [bool] CanExecute([object]$keyPress, [CommandContext]$context) {
        return $keyPress.VirtualKeyCode -eq [Constants]::KEY_H
    }

    [void] Execute([object]$keyPress, [CommandContext]$context) {
        $state = $context.State
        $repos = $state.GetRepositories()
        $currentIndex = $state.GetCurrentIndex()
        
        if ($repos.Count -eq 0) { return }
        
        $currentRepo = $repos[$currentIndex]
        $repoPath = $currentRepo.FullPath
        
        # Access service via RepoManager or Context
        if ($context.HiddenReposService) {
            
            # Check if already hidden (Toggle logic)
            if ($context.HiddenReposService.IsHidden($repoPath)) {
                # Unhide
                $context.HiddenReposService.RemoveFromHidden($repoPath)
                $context.Console.WriteLineColored("Unhided: $($currentRepo.Name)", [Constants]::ColorSuccess)
                Start-Sleep -Milliseconds 500
            } 
            else {
                # Hide
                $context.HiddenReposService.AddToHidden($repoPath)
                
                # If hidden items are not shown, remove from current view locally to avoid full reload flicker
                if (-not $context.HiddenReposService.GetShowHiddenState()) {
                    # Remove from observable list
                    $repos.RemoveAt($currentIndex)
                    $state.SetRepositories($repos)
                    
                    # Adjust index if needed
                    if ($currentIndex -ge $repos.Count) {
                        $state.SetCurrentIndex([Math]::Max(0, $repos.Count - 1))
                    }
                    
                    $state.MarkForFullRedraw()
                    return
                }
            }
            
            # If we are here, it means we unhided OR we hided but showHidden is true. 
            # In both cases, we need to refresh to update the (Hidden) status visual or the list.
            # A full reload IS NOW FAST thanks to Cache.
            $context.RepoManager.LoadRepositories()
            $state.SetRepositories($context.RepoManager.GetRepositories())
            
            # Restore selection if possible
            $newRepos = $state.GetRepositories()
            for ($i = 0; $i -lt $newRepos.Count; $i++) {
                if ($newRepos[$i].FullPath -eq $repoPath) {
                    $state.SetCurrentIndex($i)
                    break
                }
            }
            
            $state.MarkForFullRedraw()
        }
    }
}
