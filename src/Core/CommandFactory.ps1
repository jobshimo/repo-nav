# IMPORTANT: INavigationCommand.ps1 and all command implementations must be loaded BEFORE this file

<#
.SYNOPSIS
    Factory for creating and registering navigation commands
    
.DESCRIPTION
    Creates instances of all available navigation commands and provides
    a registry for command lookup and execution.
    
.NOTES
    Implements Factory Pattern for command creation
#>

class CommandFactory {
    hidden [System.Collections.ArrayList] $commands
    
    # Constructor
    CommandFactory() {
        $this.commands = [System.Collections.ArrayList]::new()
        $this.RegisterCommands()
    }
    
    <#
    .SYNOPSIS
        Registers all available commands
    #>
    hidden [void] RegisterCommands() {
        # Navigation commands
        $this.commands.Add([ExitCommand]::new())
        $this.commands.Add([NavigationCommand]::new())
        $this.commands.Add([RepositoryCommand]::new())
        
        # Git commands
        $this.commands.Add([GitCommand]::new())
        
        # Repository management commands
        $this.commands.Add([FavoriteCommand]::new())
        $this.commands.Add([AliasCommand]::new())
        $this.commands.Add([NpmCommand]::new())
        $this.commands.Add([RepositoryManagementCommand]::new())
        
        # Preferences command
        $this.commands.Add([PreferencesCommand]::new())
    }
    
    <#
    .SYNOPSIS
        Gets all registered commands
    #>
    [System.Collections.ArrayList] GetCommands() {
        return $this.commands
    }
    
    <#
    .SYNOPSIS
        Finds a command that can execute the given key press
    #>
    [INavigationCommand] FindCommand([object]$keyPress, [hashtable]$context) {
        foreach ($command in $this.commands) {
            if ($command.CanExecute($keyPress, $context)) {
                return $command
            }
        }
        return $null
    }
    
    <#
    .SYNOPSIS
        Gets descriptions of all registered commands
    #>
    [string[]] GetCommandDescriptions() {
        $descriptions = [System.Collections.Generic.List[string]]::new()
        foreach ($command in $this.commands) {
            $descriptions.Add($command.GetDescription())
        }
        return $descriptions.ToArray()
    }
}
