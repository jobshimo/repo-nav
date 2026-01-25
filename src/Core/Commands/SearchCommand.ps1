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
        
        # Get all repositories from current view (respects container navigation)
        $allRepos = $state.GetRepositories()
        
        if ($null -eq $allRepos -or $allRepos.Count -eq 0) {
            return
        }
        
        # Get currently selected repository
        $currentIndex = $state.GetCurrentIndex()
        $currentRepo = $null
        if ($currentIndex -lt $allRepos.Count) {
            $currentRepo = $allRepos[$currentIndex]
        }
        
        # Create and show search view
        $searchView = [SearchView]::new($console, $renderer, $locService)
        $result = $searchView.Show($allRepos, $currentRepo)
        
        # Process result
        if (-not $result.Cancelled -and $null -ne $result.SelectedRepo) {
            # Update navigation state with selected repository
            if ($result.SelectedIndex -ge 0) {
                $state.SetCurrentIndex($result.SelectedIndex)
            }
        }
        
        # Always request full redraw to restore normal view
        $state.MarkForFullRedraw()
    }
}
