<#
.SYNOPSIS
    Repository command - handles ENTER key to open a repository
    
.DESCRIPTION
    Changes directory to the selected repository and stops the navigation loop.
    
.NOTES
    Implements INavigationCommand interface
    Key: ENTER
    
    IMPORTANT: INavigationCommand.ps1 must be loaded BEFORE this file
#>

class RepositoryCommand : INavigationCommand {
    # Dependencies
    [object] $Console      # ConsoleHelper
    [object] $Renderer     # UIRenderer
    
    # Constructor
    RepositoryCommand([object]$console, [object]$renderer) {
        $this.Console = $console
        $this.Renderer = $renderer
    }
    
    <#
    .SYNOPSIS
        Can execute if there's a selected repository
    #>
    [bool] CanExecute([object]$state) {
        $repo = $state.GetSelectedRepository()
        return $null -ne $repo
    }
    
    <#
    .SYNOPSIS
        Opens the selected repository and stops navigation
    #>
    [void] Execute([object]$state, [hashtable]$context) {
        $selectedRepo = $state.GetSelectedRepository()
        
        if ($null -eq $selectedRepo) {
            return
        }
        
        # Clear screen and show message
        $this.Console.ClearScreen()
        $this.Renderer.RenderSuccess("Opening: $($selectedRepo.Name)")
        
        # Change directory
        Set-Location $selectedRepo.FullPath
        
        # Stop the loop
        $state.Stop()
    }
    
    <#
    .SYNOPSIS
        Returns command description
    #>
    [string] GetDescription() {
        return "Open repository"
    }
}
