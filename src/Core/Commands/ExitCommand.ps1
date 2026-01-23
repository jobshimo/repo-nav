# IMPORTANT: INavigationCommand.ps1 must be loaded BEFORE this file

class ExitCommand : INavigationCommand {
    [string] GetDescription() {
        return "Exit navigation (Q/ESC)"
    }

    [bool] CanExecute([System.ConsoleKeyInfo]$keyPress, [hashtable]$context) {
        $key = $keyPress.Key
        return $key -eq [System.ConsoleKey]::Q -or $key -eq [System.ConsoleKey]::Escape
    }

    [void] Execute([System.ConsoleKeyInfo]$keyPress, [hashtable]$context) {
        $state = $context.State
        
        # Set exit state to "Cancelled"
        $state.SetExitState("Cancelled")
        
        # Stop the navigation loop
        $state.Stop()
    }
}

