# IMPORTANT: INavigationCommand.ps1 must be loaded BEFORE this file

class NavigationCommand : INavigationCommand {
    [string] GetDescription() {
        return "Navigate (UP/DOWN/LEFT arrows)"
    }

    [bool] CanExecute([object]$keyPress, [hashtable]$context) {
        $key = $keyPress.VirtualKeyCode
        return $key -eq [Constants]::KEY_UP_ARROW -or 
               $key -eq [Constants]::KEY_DOWN_ARROW -or
               $key -eq [Constants]::KEY_LEFT_ARROW
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


