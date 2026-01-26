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
        Registers all available commands dynamically using Reflection (OCP)
    #>
    hidden [void] RegisterCommands() {
        $baseType = [INavigationCommand]
        
        # In PowerShell, classes defined in scripts are generated in a dynamic assembly.
        # We scan all assemblies to find types inheriting from INavigationCommand.
        $assemblies = [System.AppDomain]::CurrentDomain.GetAssemblies()
        
        foreach ($assembly in $assemblies) {
            try {
                # Skip system assemblies to speed up
                if ($assembly.FullName -match "^System|^Microsoft|^mscorlib") { continue }
                
                $types = $assembly.GetTypes()
                foreach ($type in $types) {
                    if ($baseType.IsAssignableFrom($type) -and $type -ne $baseType) {
                        try {
                            # Create instance and add to list
                            # Ensure we don't add duplicates if type is defined multiple times (rare in this setup)
                            if (-not $this.ContainsCommandType($type)) {
                                $instance = [Activator]::CreateInstance($type)
                                $this.commands.Add($instance)
                            }
                        }
                        catch {
                            # Skip types that can't be instantiated (e.g. abstract)
                        }
                    }
                }
            }
            catch {
                # Ignore assemblies that don't allow type enumeration
            }
        }
    }
    
    hidden [bool] ContainsCommandType($type) {
        foreach ($cmd in $this.commands) {
            if ($cmd.GetType() -eq $type) { return $true }
        }
        return $false
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
    [INavigationCommand] FindCommand([object]$keyPress, [CommandContext]$context) {
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
