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
    
    .PARAMETER keyPress
        The key press object to evaluate
    
    .PARAMETER context
        CommandContext with dependencies (State, RepoManager, Renderer, etc.)
    
    .RETURNS
        True if the command can execute, False otherwise
    #>
    [bool] CanExecute([object]$keyPress, [CommandContext]$context) {
        throw "CanExecute() must be implemented by derived class"
    }
    
    <#
    .SYNOPSIS
        Executes the command
    
    .PARAMETER keyPress
        The key press object that triggered the command
    
    .PARAMETER context
        CommandContext with dependencies (State, RepoManager, Renderer, etc.)
    #>
    [void] Execute([object]$keyPress, [CommandContext]$context) {
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

