# IMPORTANT: CommandFactory.ps1 must be loaded BEFORE this file

<#
.SYNOPSIS
    Input handler that dispatches key presses to appropriate commands
    
.DESCRIPTION
    Processes user input (key presses) and finds the appropriate command
    to execute using the CommandFactory. Implements the Chain of Responsibility
    pattern where each command checks if it can handle the input.
    
.NOTES
    This is the main input dispatcher for the navigation loop
#>

class InputHandler {
    hidden [CommandFactory] $factory
    
    # Constructor
    InputHandler([CommandFactory]$factory) {
        if ($null -eq $factory) {
            throw "CommandFactory cannot be null"
        }
        $this.factory = $factory
    }
    
    <#
    .SYNOPSIS
        Handles a key press by finding and executing the appropriate command
        
    .PARAMETER keyPress
        The key press from Read-Host -AsSecureString or [Console]::ReadKey()
        
    .PARAMETER context
        Context hashtable containing State, RepoManager, etc.
        
    .RETURNS
        $true if a command was executed, $false if no command could handle the input
    #>
    [bool] HandleInput([object]$keyPress, [hashtable]$context) {
        if ($null -eq $keyPress) {
            return $false
        }
        
        if ($null -eq $context) {
            throw "Context cannot be null"
        }
        
        # Find a command that can execute this key press
        $command = $this.factory.FindCommand($keyPress, $context)
        
        if ($null -ne $command) {
            try {
                # Execute the command
                $command.Execute($keyPress, $context)
                return $true
            }
            catch {
                Write-Error "Error executing command: $_"
                return $false
            }
        }
        
        # No command could handle this input
        return $false
    }
    
    <#
    .SYNOPSIS
        Gets all available commands from the factory
    #>
    [System.Collections.ArrayList] GetCommands() {
        return $this.factory.GetCommands()
    }
    
    <#
    .SYNOPSIS
        Gets descriptions of all available commands
    #>
    [string[]] GetCommandDescriptions() {
        return $this.factory.GetCommandDescriptions()
    }
}
