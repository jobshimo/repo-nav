<#
.SYNOPSIS
    Navigation command - handles UP and DOWN arrow keys
    
.DESCRIPTION
    Moves selection between repositories with wraparound.
    Uses partial redraw for performance optimization.
    
.NOTES
    Implements INavigationCommand interface
    Keys: UP_ARROW, DOWN_ARROW
    
    IMPORTANT: INavigationCommand.ps1 must be loaded BEFORE this file
#>

class NavigationCommand : INavigationCommand {
    # Configuration
    [string] $Direction    # "Up" or "Down"
    
    # Constructor
    NavigationCommand([string]$direction) {
        if ($direction -ne "Up" -and $direction -ne "Down") {
            throw "Direction must be 'Up' or 'Down'"
        }
        $this.Direction = $direction
    }
    
    <#
    .SYNOPSIS
        Can always execute if there are repositories
    #>
    [bool] CanExecute([object]$state) {
        return $state.GetTotalCount() -gt 0
    }
    
    <#
    .SYNOPSIS
        Moves selection up or down
    #>
    [void] Execute([object]$state, [hashtable]$context) {
        # Update selection
        if ($this.Direction -eq "Up") {
            $state.SelectPrevious()
        }
        else {
            $state.SelectNext()
        }
        
        # Mark for partial redraw (only affected items)
        $state.MarkForPartialRedraw()
    }
    
    <#
    .SYNOPSIS
        Returns command description
    #>
    [string] GetDescription() {
        return "Navigate $($this.Direction)"
    }
}
