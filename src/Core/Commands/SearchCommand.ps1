# IMPORTANT: INavigationCommand.ps1 and SearchView.ps1 must be loaded BEFORE this file

<#
.SYNOPSIS
    SearchCommand - Activates repository search mode with 'S' key
    
.DESCRIPTION
    Following Command Pattern:
    - Encapsulates the search action
    - Triggered by 'S' key press
    - Opens SearchView for interactive filtering
    
.NOTES
    Integrates with existing navigation state to update selection
#>

class SearchCommand : INavigationCommand {
    
    [string] GetDescription() {
        return "Search repositories (S)"
    }
    
    [bool] CanExecute([object]$keyPress, [hashtable]$context) {
        # Activate on 'S' or 's' key
        $char = $keyPress.Character
        return ($char -eq 'S' -or $char -eq 's')
    }
    
    [void] Execute([object]$keyPress, [hashtable]$context) {
        $state = $context.State
        $console = $context.Console
        $renderer = $context.Renderer
        $locService = $context.LocalizationService
        $repoManager = $context.RepoManager
        $basePath = $context.BasePath
        
        # Get ALL repositories recursively (not just current folder)
        $allRepos = $repoManager.GetAllRepositoriesRecursive($basePath)
        
        if ($null -eq $allRepos -or $allRepos.Count -eq 0) {
            return
        }
        
        # Get currently selected repository
        $currentIndex = $state.GetCurrentIndex()
        $currentRepos = $state.GetRepositories()
        $currentRepo = $null
        if ($currentIndex -lt $currentRepos.Count) {
            $currentRepo = $currentRepos[$currentIndex]
        }
        
        # Create and show search view
        $searchView = [SearchView]::new($console, $renderer, $locService)
        $result = $searchView.Show($allRepos, $currentRepo)
        
        # Process result
        if (-not $result.Cancelled -and $null -ne $result.SelectedRepo) {
            $selectedRepo = $result.SelectedRepo
            
            # Check if selected repo is in current view
            $currentViewRepos = $state.GetRepositories()
            $indexInCurrentView = -1
            for ($i = 0; $i -lt $currentViewRepos.Count; $i++) {
                if ($currentViewRepos[$i].FullPath -eq $selectedRepo.FullPath) {
                    $indexInCurrentView = $i
                    break
                }
            }
            
            if ($indexInCurrentView -ge 0) {
                # Repo is in current view - just select it
                $state.SetCurrentIndex($indexInCurrentView)
            } else {
                # Repo is in a different folder - navigate to its parent
                $parentPath = Split-Path $selectedRepo.FullPath -Parent
                $repoManager.LoadRepositories($parentPath)
                $state.SetRepositories($repoManager.GetRepositories())
                $state.SetCurrentPath($parentPath)
                
                # Find and select the repo in the new view
                $newRepos = $state.GetRepositories()
                for ($i = 0; $i -lt $newRepos.Count; $i++) {
                    if ($newRepos[$i].FullPath -eq $selectedRepo.FullPath) {
                        $state.SetCurrentIndex($i)
                        break
                    }
                }
            }
        }
        
        # Always request full redraw to restore normal view
        $state.MarkForFullRedraw()
    }
}
