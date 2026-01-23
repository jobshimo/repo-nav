<#
.SYNOPSIS
    Interface for navigation commands following Command Pattern
    
.DESCRIPTION
    All navigation commands must implement this interface.
    This enables:
    - Command Pattern for decoupling input handling from execution
    - Open/Closed Principle: Add new commands without modifying existing code
    - Single Responsibility: Each command handles one specific action
    - Testability: Commands can be tested in isolation
    
.NOTES
    This is an abstract base class that defines the contract for all commands.
    PowerShell doesn't have true interfaces, so we use a class with abstract-like methods.
#>

class INavigationCommand {
    <#
    .SYNOPSIS
        Determines if the command can be executed in the current state
    
    .PARAMETER state
        The current NavigationState
    
    .RETURNS
        True if the command can execute, False otherwise
    #>
    [bool] CanExecute([object]$state) {
        throw "CanExecute() must be implemented by derived class"
    }
    
    <#
    .SYNOPSIS
        Executes the command
    
    .PARAMETER state
        The NavigationState to modify
    
    .PARAMETER context
        Hashtable with dependencies (RepoManager, Renderer, Console, etc.)
    #>
    [void] Execute([object]$state, [hashtable]$context) {
        throw "Execute() must be implemented by derived class"
    }
    
    <#
    .SYNOPSIS
        Gets a human-readable description of what this command does
    
    .RETURNS
        String description
    #>
    [string] GetDescription() {
        throw "GetDescription() must be implemented by derived class"
    }
}
