<#
.SYNOPSIS
    Orchestrates rendering based on navigation state (Strategy Pattern)
    
.DESCRIPTION
    Decides what and how to render based on state flags:
    - Full redraw: Complete screen refresh (header, menu, all items, footer)
    - Partial redraw: Only affected items (previous/current selection + footer)
    
    Following SOLID principles:
    - SRP: Only handles rendering orchestration logic
    - OCP: Can be extended with new rendering strategies
    - DIP: Depends on UIRenderer and ConsoleHelper abstractions
    
.NOTES
    This implements a variation of the Strategy Pattern where the strategy
    is determined by the state's dirty flags (RequiresFullRedraw, RequiresPartialRedraw)
#>

class RenderOrchestrator {
    # Dependencies (injected)
    [object] $Renderer     # UIRenderer
    [object] $Console      # ConsoleHelper
    [int] $CursorStartLine # Line where repository list starts
    
    # Constructor with Dependency Injection
    RenderOrchestrator([object]$renderer, [object]$console, [int]$cursorStartLine) {
        $this.Renderer = $renderer
        $this.Console = $console
        $this.CursorStartLine = $cursorStartLine
    }
    
    #region Public Rendering Methods
    
    <#
    .SYNOPSIS
        Renders based on state flags (main entry point)
    #>
    [void] RenderIfNeeded([NavigationState]$state) {
        if ($state.RequiresFullRedraw) {
            $this.RenderFull($state)
            $state.ClearRedrawFlags()
        }
        elseif ($state.RequiresPartialRedraw) {
            $this.RenderPartial($state)
            $state.ClearRedrawFlags()
        }
    }
    
    <#
    .SYNOPSIS
        Forces a complete screen redraw
    #>
    [void] RenderFull([NavigationState]$state) {
        $this.Console.ClearScreen()
        
        # Header
        $this.Renderer.RenderHeader("REPOSITORY NAVIGATOR")
        
        # Menu
        $this.Renderer.RenderMenu()
        
        # All repository items
        $repos = $state.Repositories
        for ($i = 0; $i -lt $repos.Count; $i++) {
            $isSelected = ($i -eq $state.SelectedIndex)
            $this.Renderer.RenderRepositoryItem($repos[$i], $isSelected)
        }
        
        # Footer with statistics
        Write-Host ""
        $selectedRepo = $state.GetSelectedRepository()
        $totalRepos = $state.GetTotalCount()
        $loadedRepos = $state.GetLoadedCount()
        $this.Renderer.RenderGitStatusFooter($selectedRepo, $totalRepos, $loadedRepos)
    }
    
    <#
    .SYNOPSIS
        Partial redraw: only affected items
    #>
    [void] RenderPartial([NavigationState]$state) {
        $startLine = $this.CursorStartLine
        $repos = $state.Repositories
        
        # Update previous item (deselect)
        if ($state.PreviousIndex -ne $state.SelectedIndex) {
            $previousRepo = $repos[$state.PreviousIndex]
            $this.Renderer.UpdateRepositoryItemAt(
                ($startLine + $state.PreviousIndex),
                $previousRepo,
                $false
            )
        }
        
        # Update current item (select)
        $currentRepo = $repos[$state.SelectedIndex]
        $this.Renderer.UpdateRepositoryItemAt(
            ($startLine + $state.SelectedIndex),
            $currentRepo,
            $true
        )
        
        # Update footer
        $footerLine = $startLine + $repos.Count + 1
        $this.Console.SetCursorPosition(0, $footerLine)
        $this.Renderer.ClearGitStatusFooter($footerLine)
        
        $totalRepos = $state.GetTotalCount()
        $loadedRepos = $state.GetLoadedCount()
        $this.Renderer.RenderGitStatusFooter($currentRepo, $totalRepos, $loadedRepos)
    }
    
    #endregion
    
    #region Specialized Rendering
    
    <#
    .SYNOPSIS
        Renders a success message and clears screen
    #>
    [void] RenderSuccess([string]$message) {
        $this.Console.ClearScreen()
        $this.Renderer.RenderSuccess($message)
    }
    
    <#
    .SYNOPSIS
        Renders a warning message and clears screen
    #>
    [void] RenderWarning([string]$message) {
        $this.Console.ClearScreen()
        $this.Renderer.RenderWarning($message)
    }
    
    <#
    .SYNOPSIS
        Renders an error message and clears screen
    #>
    [void] RenderError([string]$message) {
        $this.Console.ClearScreen()
        $this.Renderer.RenderError($message)
    }
    
    #endregion
}
