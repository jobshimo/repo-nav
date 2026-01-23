# IMPORTANT: INavigationCommand.ps1 must be loaded BEFORE this file

class RepositoryCommand : INavigationCommand {
    [string] GetDescription() {
        return "Open repository (ENTER)"
    }

    [bool] CanExecute([System.ConsoleKeyInfo]$keyPress, [hashtable]$context) {
        return $keyPress.Key -eq [System.ConsoleKey]::Enter
    }

    [void] Execute([System.ConsoleKeyInfo]$keyPress, [hashtable]$context) {
        $state = $context.State
        $repos = $state.GetRepositories()
        $currentIndex = $state.GetCurrentIndex()
        
        if ($repos.Count -eq 0) { return }
        
        $selectedRepo = $repos[$currentIndex]
        
        # Set exit state to "OpenRepository"
        $state.SetExitState("OpenRepository")
        
        # Stop the navigation loop
        $state.Stop()
    }
}
