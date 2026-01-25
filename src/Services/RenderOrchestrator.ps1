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
    [int] $CursorStartLine # Calculated line where repository list starts
    [UserPreferencesService] $PreferencesService # For Menu Mode
    
    # Constructor with Dependency Injection
    RenderOrchestrator([object]$renderer, [object]$console, [int]$initialCursorStartLine) {
        $this.Renderer = $renderer
        $this.Console = $console
        $this.CursorStartLine = $initialCursorStartLine
        $this.PreferencesService = [UserPreferencesService]::new()
    }
    
    #region Public Rendering Methods

    <#
    .SYNOPSIS
        Initializes the screen and adjusts layout to fit window
    #>
    [void] Initialize([object]$state) {
        # First render to establish the layout components (Header, Menu height, etc.)
        # This calculates the properties like CursorStartLine
        $this.RenderFull($state)
        
        # Now that we know the interface height, calculate the correct Viewport size (PageSize)
        $state.UpdateWindowSize($this.CursorStartLine)
        
        # If the window size calculation changed the PageSize, we need to redraw
        # to fill the empty space or trim the list
        if ($state.RequiresFullRedraw) {
            $this.RenderFull($state)
            $state.RequiresFullRedraw = $false
        }
    }
    
    <#
    .SYNOPSIS
        Renders based on state flags (main entry point)
    #>
    [void] RenderIfNeeded([object]$state) {
        # Check if window resized - Pass current CursorStartLine as header height approximation
        # (It will be corrected on next full redraw)
        $state.UpdateWindowSize($this.CursorStartLine)

        if ($state.RequiresFullRedraw) {
            $this.RenderFull($state)
            # Clearing flags logic might need to be specific if methods exist, 
            # but usually bool properties can be set to false directly if accessible
            $state.RequiresFullRedraw = $false
        }
        elseif ($state.SelectionChanged -or $state.ViewportChanged) {
            $this.RenderPartial($state)
            $state.SelectionChanged = $false
            # ViewportChanged is cleared inside RenderPartial, but to be safe:
            $state.ViewportChanged = $false
        }
    }
    
    <#
    .SYNOPSIS
        Forces a complete screen redraw
    #>
    [void] RenderFull([object]$state) {
        $this.Console.ClearScreen()
        
        # Load preferences to check MenuMode
        $prefs = $this.PreferencesService.LoadPreferences()
        $menuMode = $prefs.display.menuMode
        
        # Header (Takes 3 lines)
        $this.Renderer.RenderHeader("REPOSITORY NAVIGATOR")
        
        # Menu (dynamic height)
        # Returns number of lines used
        $menuLines = $this.Renderer.RenderMenu($menuMode)
        
        # Calculate cursor start line dynamically
        # Header (3) + Menu (menuLines)
        $this.CursorStartLine = 3 + $menuLines
        
        # Calculate correct PageSize based on NEW CursorStartLine
        # This prevents scrolling artifacts when switching between Menu Modes
        $state.UpdateWindowSize($this.CursorStartLine)
        
        # Explicitly enforce start position to match partial updates
        $this.Console.SetCursorPosition(0, $this.CursorStartLine)
        
        # Render visibly repository list (viewport aware)
        $this.Renderer.RenderRepositoryList($state, $this.CursorStartLine)
        
        # Footer with statistics
        # Calculate footer line to ensure consistency with RenderPartial
        $footerLine = $this.CursorStartLine + $state.PageSize + 1
        $this.Console.SetCursorPosition(0, $footerLine)
        
        $selectedRepo = $state.GetSelectedRepository()
        $totalRepos = $state.GetTotalCount()
        $loadedRepos = $state.GetLoadedCount()
        $currentIndex = $state.GetCurrentIndex()
        $this.Renderer.RenderGitStatusFooter($selectedRepo, $totalRepos, $loadedRepos, $currentIndex)
    }
    
    <#
    .SYNOPSIS
        Partial redraw: only affected items or viewport scroll
    #>
    [void] RenderPartial([object]$state) {
        $startLine = $this.CursorStartLine
        $pageSize = $state.PageSize
        
        # Determine if we need to scroll.
        # Even if ViewportChanged is FALSE in state (logic bug elsewhere?).
        # Double check if current index is visible.
        if ($state.SelectedIndex -lt $state.ViewportStart -or 
            $state.SelectedIndex -ge ($state.ViewportStart + $pageSize)) {
            
            # Auto-correct viewport if out of sync
            if ($state.SelectedIndex -lt $state.ViewportStart) {
                $state.ViewportStart = $state.SelectedIndex
            } else {
                 $state.ViewportStart = [Math]::Max(0, $state.SelectedIndex - $pageSize + 1)
            }
            $state.ViewportChanged = $true
        }

        # Handle Viewport Scroll (redraw full list area)
        if ($state.ViewportChanged) {
            $this.Renderer.RenderRepositoryList($state, $startLine)
            $state.ViewportChanged = $false 
        } 
        else {
            # Handle localized selection change
            $repos = $state.Repositories
            $viewportStart = $state.ViewportStart
             
            # Update previous item (deselect) - only if in specific viewport logic
            # Since selection must move from one to another, usually both are in viewport or viewport changes.
            # But let's be safe.
            
            if ($state.PreviousIndex -ge $viewportStart -and $state.PreviousIndex -lt ($viewportStart + $pageSize)) {
                 $prevRelIndex = $state.PreviousIndex - $viewportStart
                 if ($prevRelIndex -ge 0) {
                    $previousRepo = $repos[$state.PreviousIndex]
                    $this.Renderer.UpdateRepositoryItemAt(
                        ($startLine + $prevRelIndex),
                        $previousRepo,
                        $false
                    )
                 }
            }
            
            # Update current item (select)
            if ($state.SelectedIndex -ge $viewportStart -and $state.SelectedIndex -lt ($viewportStart + $pageSize)) {
                $currRelIndex = $state.SelectedIndex - $viewportStart
                if ($currRelIndex -ge 0) {
                    $currentRepo = $repos[$state.SelectedIndex]
                    $this.Renderer.UpdateRepositoryItemAt(
                        ($startLine + $currRelIndex),
                        $currentRepo,
                        $true
                    )
                }
            }
        }
        
        # Update footer - Fixed position based on PageSize
        $footerLine = $startLine + $pageSize + 1       
        
        # Clear the gap line just in case (to prevent artifacts)
        $this.Console.SetCursorPosition(0, $footerLine - 1)
        $this.Console.ClearCurrentLine()
        
        # Clear line 2 (counters) and line 3 (git status) to avoid residuals
        $this.Console.SetCursorPosition(0, $footerLine + 1)
        $this.Console.ClearCurrentLine()
        $this.Console.SetCursorPosition(0, $footerLine + 2)
        $this.Console.ClearCurrentLine()
        
        # Position at footer start and render
        $this.Console.SetCursorPosition(0, $footerLine)
        $totalRepos = $state.GetTotalCount()
        $loadedRepos = $state.GetLoadedCount()
        $this.Renderer.RenderGitStatusFooter($state.GetSelectedRepository(), $totalRepos, $loadedRepos, $state.SelectedIndex)
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
