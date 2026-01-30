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
    [bool] HandleInput([object]$keyPress, [CommandContext]$context) {
        if ($null -eq $keyPress) {
            return $false
        }
        
        if ($null -eq $context) {
            throw "Context cannot be null"
        }
        
        # --- Focus Management (Tab Navigation) ---
        # --- Focus Management (Tab Navigation) ---
        # Robust check for Tab: Key 'Tab', VirtualKeyCode 9, or Char 9
        if ($keyPress.Key -eq 'Tab' -or $keyPress.VirtualKeyCode -eq 9 -or $keyPress.KeyChar -eq [char]9) {
            $context.State.ToggleFocus()
            return $true
        }
        
        # Header Focus Input Handling
        if ($context.State.IsHeaderFocused()) {
            if ($keyPress.Key -eq 'Enter' -or $keyPress.KeyChar -eq [char]13 -or $keyPress.VirtualKeyCode -eq 13) {
                # Delegate to SwitchPathCommand (Simulate 'P')
                $fakeKey = [PSCustomObject]@{ Key = 'P'; KeyChar = 'P'; Modifiers = 0; VirtualKeyCode = [Constants]::KEY_P }
                $cmd = $this.factory.FindCommand($fakeKey, $context)
                if ($null -ne $cmd) {
                    $cmd.Execute($fakeKey, $context)
                    return $true
                }
            }
            elseif ($keyPress.Key -eq 'Escape' -or $keyPress.VirtualKeyCode -eq 27 -or $keyPress.KeyChar -eq [char]27) {
                $context.State.SetFocus("List")
                return $true
            }
            elseif ($keyPress.Key -eq 'UpArrow' -or $keyPress.Key -eq 'DownArrow') {
                 # Consume navigation keys when focus is on Header
                 return $true
            }
        }
        
        # Generic Dispatch (List Focus or Global Commands)
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
