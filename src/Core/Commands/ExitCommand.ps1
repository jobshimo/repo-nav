# IMPORTANT: INavigationCommand.ps1 must be loaded BEFORE this file

class ExitCommand : INavigationCommand {
    [string] GetDescription() {
        return "Exit navigation (Q/ESC)"
    }

    [bool] CanExecute([object]$keyPress, [CommandContext]$context) {
        $key = $keyPress.VirtualKeyCode
        return $key -eq [Constants]::KEY_Q -or $key -eq [Constants]::KEY_ESC
    }

    [void] Execute([object]$keyPress, [CommandContext]$context) {
        $state = $context.State
        
        # Set exit state to "Cancelled"
        $state.SetExitState("Cancelled")
        
        # Stop the navigation loop
        $state.Stop()
    }
}



