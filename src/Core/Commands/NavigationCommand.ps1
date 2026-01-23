# IMPORTANT: INavigationCommand.ps1 must be loaded BEFORE this file

class NavigationCommand : INavigationCommand {
    [string] GetDescription() {
        return "Navigate (UP/DOWN arrows)"
    }

    [bool] CanExecute([System.ConsoleKeyInfo]$keyPress, [hashtable]$context) {
        $key = $keyPress.Key
        return $key -eq [System.ConsoleKey]::UpArrow -or $key -eq [System.ConsoleKey]::DownArrow
    }

    [void] Execute([System.ConsoleKeyInfo]$keyPress, [hashtable]$context) {
        $state = $context.State
        $repos = $state.GetRepositories()
        
        if ($repos.Count -eq 0) { return }
        
        $currentIndex = $state.GetCurrentIndex()
        $key = $keyPress.Key
        
        # Calculate new index
        if ($key -eq [System.ConsoleKey]::UpArrow) {
            if ($currentIndex -gt 0) {
                $state.SetCurrentIndex($currentIndex - 1)
            }
            else {
                $state.SetCurrentIndex($repos.Count - 1)
            }
        }
        elseif ($key -eq [System.ConsoleKey]::DownArrow) {
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
