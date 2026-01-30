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
        # Clean Code: The main method just orchestrates the high-level logic
        $commandTypes = $this.FindCommandTypes()
        
        foreach ($type in $commandTypes) {
            $this.RegisterOneCommand($type)
        }

        # Explicitly attempt to register GitFlowCommand to ensure it's loaded
        # This handles cases where reflection might miss dynamically compiled classes
        $gitFlowType = "GitFlowCommand" -as [type]
        if ($null -ne $gitFlowType) {
            $this.RegisterOneCommand($gitFlowType)
        }
        
        # Explicitly attempt to register PreferencesCommand
        $prefType = "PreferencesCommand" -as [type]
        if ($null -ne $prefType) {
            $this.RegisterOneCommand($prefType)
        }

        # Explicitly attempt to register NpmCommand
        $npmType = "NpmCommand" -as [type]
        if ($null -ne $npmType) {
            $this.RegisterOneCommand($npmType)
        }
        
        # Explicitly register Hidden Repos commands
        $hideType = "HideRepoCommand" -as [type]
        if ($null -ne $hideType) {
            $this.RegisterOneCommand($hideType)
        }
        
        $toggleType = "ToggleHiddenVisibilityCommand" -as [type]
        if ($null -ne $toggleType) {
            $this.RegisterOneCommand($toggleType)
        }
        
        $switchType = "SwitchPathCommand" -as [type]
        if ($null -ne $switchType) {
            $this.RegisterOneCommand($switchType)
        }
    }

    hidden [System.Collections.ArrayList] FindCommandTypes() {
        $foundTypes = [System.Collections.ArrayList]::new()
        $baseType = [INavigationCommand]
        
        $assemblies = [System.AppDomain]::CurrentDomain.GetAssemblies()
        
        foreach ($assembly in $assemblies) {
            if ($this.IsSystemAssembly($assembly)) { continue }
            
            $types = $this.GetTypesSafe($assembly)
            
            foreach ($type in $types) {
                if ($baseType.IsAssignableFrom($type) -and $type -ne $baseType) {
                    $foundTypes.Add($type)
                }
            }
        }
        return $foundTypes
    }
    
    hidden [bool] IsSystemAssembly($assembly) {
        return $assembly.FullName -match "^System|^Microsoft|^mscorlib|^Anonymously"
    }

    hidden [array] GetTypesSafe($assembly) {
        try {
            return $assembly.GetTypes()
        }
        catch {
            return @()
        }
    }

    hidden [void] RegisterOneCommand($type) {
        if (-not $this.ContainsCommandType($type)) {
            try {
                $instance = [Activator]::CreateInstance($type)
                $this.commands.Add($instance)
            }
            catch {
                # Skip types that can't be instantiated
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
