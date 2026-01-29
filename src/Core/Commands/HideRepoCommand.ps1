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
        
        # Get current repository
        $currentRepo = $repos[$currentIndex]
        
        # Don't allow hiding containers (optional business rule)
        if ($currentRepo.IsContainer) { return }
        
        # Get HiddenReposService from context
        $hiddenService = $context.HiddenReposService
        if ($null -eq $hiddenService) { return }
        
        # Add to hidden list
        $hiddenService.AddToHidden($currentRepo.Name)
        
        # Remove from current list if not showing hidden
        if (-not $hiddenService.GetShowHiddenState()) {
            $repos.RemoveAt($currentIndex)
            $state.SetRepositories($repos)
            
            # Adjust index if necessary
            if ($currentIndex -ge $repos.Count) {
                $state.SetCurrentIndex([Math]::Max(0, $repos.Count - 1))
            }
        }
        
        # Mark for redraw
        $state.MarkForFullRedraw()
    }
}
