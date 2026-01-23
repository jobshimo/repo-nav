<#
.SYNOPSIS
    Exit command - handles Q and ESC keys
    
.DESCRIPTION
    Stops the navigation loop and displays a cancellation message.
    This is the simplest command, serving as a proof of concept.
    
.NOTES
    Implements INavigationCommand interface
    Keys: Q, ESC
    
    IMPORTANT: INavigationCommand.ps1 must be loaded BEFORE this file
#>

class ExitCommand : INavigationCommand {
    # Dependencies
    [object] $Console      # ConsoleHelper
    [object] $Renderer     # UIRenderer
    
    # Constructor
    ExitCommand([object]$console, [object]$renderer) {
        $this.Console = $console
        $this.Renderer = $renderer
    }
    
    <#
    .SYNOPSIS
        Can always execute (no preconditions)
    #>
    [bool] CanExecute([object]$state) {
        return $true
    }
    
    <#
    .SYNOPSIS
        Stops navigation and displays cancellation message
    #>
    [void] Execute([object]$state, [hashtable]$context) {
        # Stop the loop
        $state.Stop()
        
        # Clear screen and show message
        $this.Console.ClearScreen()
        $this.Renderer.RenderWarning("Navigation cancelled.")
    }
    
    <#
    .SYNOPSIS
        Returns command description
    #>
    [string] GetDescription() {
        return "Exit navigation"
    }
}
