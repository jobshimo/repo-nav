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
    [HiddenReposService] $HiddenReposService # For visibility indicator
    
    # Constructor with Dependency Injection
    RenderOrchestrator([object]$renderer, [object]$console, [int]$initialCursorStartLine, [HiddenReposService]$hiddenReposService) {
        $this.Renderer = $renderer
        $this.Console = $console
        $this.CursorStartLine = $initialCursorStartLine
        $this.PreferencesService = [UserPreferencesService]::new()
        $this.HiddenReposService = $hiddenReposService
    }
    
    #region Public Rendering Methods

    <#
    .SYNOPSIS
        Initializes the screen and adjusts layout to fit window
    #>
    [void] Initialize([object]$state) {
        # Single render that establishes layout and calculates viewport
        # RenderFull already calls UpdateWindowSize internally, so no double rendering needed
        $this.RenderFull($state)
        
        # Clear any flags set during initialization
        $state.RequiresFullRedraw = $false
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
            $state.RequiresFullRedraw = $false
            $state.RequiresListRedraw = $false
        }
        elseif ($state.RequiresListRedraw) {
            $this.RenderListOnly($state)
            $state.RequiresListRedraw = $false
            # Should also clear selection changed as we redrew everything
            $state.SelectionChanged = $false
        }
        elseif ($state.SelectionChanged -or $state.ViewportChanged) {
            $this.RenderPartial($state)
            $state.SelectionChanged = $false
            $state.ViewportChanged = $false
        }
    }
    
    <#
    .SYNOPSIS
        Renders the repository list and footer (no header/menu redraw)
        Used when list changes but layout doesn't require full screen clear
    #>
    [void] RenderListOnly([object]$state) {
        $this.Console.HideCursor()
        
        # Ensure correct start position
        $startLine = $this.CursorStartLine
        $this.Console.SetCursorPosition(0, $startLine)
        
        # Render list (UIRenderer now clears extra lines if list is shorter)
        $this.Renderer.RenderRepositoryList($state, $startLine)
        
        # Update footer to reflect new totals and visibility state
        # No flickering here since we don't ClearScreen
        $footerLine = $startLine + $state.PageSize + 1
        $this.Console.SetCursorPosition(0, $footerLine)
        
        $totalItems = $state.GetTotalCount()
        $totalRepos = $state.GetRepoCount()
        $loadedRepos = $state.GetLoadedCount()
        
        $showHidden = $false
        if ($this.HiddenReposService) {
             $showHidden = $this.HiddenReposService.GetShowHiddenState()
        }
        
        $this.Renderer.RenderGitStatusFooter($state.GetSelectedRepository(), $totalItems, $totalRepos, $loadedRepos, $state.SelectedIndex, $showHidden)
    }
    
    <#
    .SYNOPSIS
        Forces a complete screen redraw
    #>
    [void] RenderFull([object]$state) {
        $this.Console.ClearScreen()
        $this.Console.SetCursorPosition(0, 0) # Ensure we start at top
        $this.Console.HideCursor() # Hide cursor for seamless redraw
        
        # Load preferences to check MenuMode
        $prefs = $this.PreferencesService.LoadPreferences()
        $menuMode = $prefs.display.menuMode
        
        # Header (Takes 3 lines)
        $pathDisplayMode = if ($prefs.display.pathDisplayMode) { $prefs.display.pathDisplayMode } else { "Path" }
        $currentPath = $state.BasePath
        
        # Determine what to show
        $headerText = "REPOSITORY NAVIGATOR"
        $subText = ""
        
        # Check for alias
        $aliasText = $null
        $aliasColor = [Constants]::ColorFavorite # Default
        
        if ($prefs.repository.pathAliases) {
            # Robust property access for paths which may contain spaces/special chars
            if ($prefs.repository.pathAliases.PSObject.Properties.Match($currentPath).Count -gt 0) {
                $aliasRaw = $prefs.repository.pathAliases."$currentPath"
                
                # Check if it's an object (New style) or string (Legacy)
                if ($aliasRaw -is [string]) {
                    $aliasText = $aliasRaw
                } 
                elseif ($aliasRaw.PSObject.Properties.Name -contains 'Text') {
                    $aliasText = $aliasRaw.Text
                    if ($aliasRaw.PSObject.Properties.Name -contains 'Color') {
                         # Convert string color to ConsoleColor
                         try {
                             $aliasColor = [System.Enum]::Parse([System.ConsoleColor], $aliasRaw.Color)
                         } catch {
                             $aliasColor = [Constants]::ColorFavorite
                         }
                    }
                }
            }
        }
        
        $highlight = ""
        $highlightColor = $aliasColor
        
        switch ($pathDisplayMode) {
            "Path" { 
                $subText = $currentPath 
            }
            "Alias" { 
                if ($aliasText) {
                    $subText = $aliasText
                    # If showing alias only, usually it's in Value color, but maybe we want custom color?
                    # For now keep uniform Value color for subtitle main text
                } else {
                    $subText = $currentPath
                }
            }
            "Both" { 
                $subText = $currentPath
                if ($aliasText) { 
                    $highlight = $aliasText
                }
            }
        }
        
        # Focus Visualization
        $borderColor = [Constants]::ColorSeparator
        if ($state.IsHeaderFocused()) {
            $borderColor = [Constants]::ColorFavorite
            if ([string]::IsNullOrEmpty($highlight)) {
                $highlight = "Press Enter to Switch"
                $highlightColor = [Constants]::ColorInfo
            } else {
                $highlight += " | Press Enter to Switch"
            }
        }
        
        $this.Renderer.RenderHeader($headerText, $subText, $highlight, $highlightColor, $borderColor)
        
        # Render breadcrumb if we're inside a container
        $breadcrumbLines = 0
        if ($state.CanGoBack()) {
            $breadcrumb = $state.GetBreadcrumb()
            if (-not [string]::IsNullOrEmpty($breadcrumb)) {
                $this.Renderer.RenderBreadcrumb($breadcrumb)
                $breadcrumbLines = 1
            }
        }
        
        # Menu (dynamic height)
        # Returns number of lines used
        $menuLines = $this.Renderer.RenderMenu($menuMode)
        
        # Calculate cursor start line dynamically
        $headerLines = if ($this.Renderer.ShouldShowHeaders()) { 3 } else { 0 }
        # Header + Breadcrumb (0 or 1) + Menu (menuLines)
        $this.CursorStartLine = $headerLines + $breadcrumbLines + $menuLines
        
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
        $totalItems = $state.GetTotalCount()
        $totalRepos = $state.GetRepoCount()
        $loadedRepos = $state.GetLoadedCount()
        $currentIndex = $state.GetCurrentIndex()
        
        $showHidden = $false
        if ($this.HiddenReposService) {
             $showHidden = $this.HiddenReposService.GetShowHiddenState()
        }
        
        $this.Renderer.RenderGitStatusFooter($selectedRepo, $totalItems, $totalRepos, $loadedRepos, $currentIndex, $showHidden)
    }
    
    <#
    .SYNOPSIS
        Partial redraw: only affected items or viewport scroll
    #>
    [void] RenderPartial([object]$state) {
        $this.Console.HideCursor()
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
        
        # Helper clears removed: UIRenderer now handles overwriting lines without clearing
        # Line 2 and 3 clears were causing flickering

        
        # Position at footer start and render
        $this.Console.SetCursorPosition(0, $footerLine)
        $totalItems = $state.GetTotalCount()
        $totalRepos = $state.GetRepoCount()
        $loadedRepos = $state.GetLoadedCount()
        
        $showHidden = $false
        if ($this.HiddenReposService) {
             $showHidden = $this.HiddenReposService.GetShowHiddenState()
        }
        
        $this.Renderer.RenderGitStatusFooter($state.GetSelectedRepository(), $totalItems, $totalRepos, $loadedRepos, $state.SelectedIndex, $showHidden)
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
