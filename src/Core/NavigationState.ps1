<#
.SYNOPSIS
    Navigation state management following State Pattern
    
.DESCRIPTION
    Encapsulates all navigation state:
    - Current selection index
    - Repository list
    - Running flag
    - Redraw flags for optimized rendering
    
    Following SOLID principles:
    - SRP: Only manages navigation state (delegates window calculations to WindowSizeCalculator)
    - OCP: Can be extended with new state properties
    - DIP: Depends on WindowSizeCalculator abstraction
    - Encapsulation: State changes through methods, not direct property access
    
.NOTES
    This class is immutable in terms of repository references but mutable for navigation state.
    Redraw flags follow a dirty flag pattern for optimized rendering.
#>

class NavigationState {
    # Current state
    [int] $SelectedIndex
    [array] $Repositories
    [bool] $IsRunning
    [string] $ExitState  # Can be: "None", "Cancelled", "OpenRepository"
    
    # Viewport state for pagination
    [int] $ViewportStart
    [int] $PageSize
    
    # Rendering optimization flags
    [bool] $RequiresFullRedraw
    [bool] $SelectionChanged
    [bool] $ViewportChanged  # New flag for scroll detection
    [int] $PreviousIndex
    
    # Hierarchical navigation state (for container folders)
    [System.Collections.Generic.Stack[hashtable]] $NavigationStack
    [string] $CurrentPath
    [string] $BasePath
    
    # Dependency for window calculations
    hidden [WindowSizeCalculator] $WindowCalculator
    
    # Constructor
    NavigationState([array]$repositories) {
        $this.Repositories = $repositories
        $this.SelectedIndex = 0
        $this.PreviousIndex = 0
        $this.IsRunning = $true
        $this.ExitState = "None"
        $this.RequiresFullRedraw = $false
        $this.SelectionChanged = $false
        
        # Initialize paging defaults
        $this.ViewportStart = 0
        $this.ViewportChanged = $false
        
        # Initialize navigation stack for hierarchical navigation
        $this.NavigationStack = [System.Collections.Generic.Stack[hashtable]]::new()
        $this.CurrentPath = $null
        $this.BasePath = $null
        
        # Create WindowSizeCalculator for size calculations
        $this.WindowCalculator = [WindowSizeCalculator]::new()
        $this.PageSize = $this.WindowCalculator.CalculateInitialPageSize()
    }
    
    # Constructor with base path (for hierarchical navigation)
    NavigationState([array]$repositories, [string]$basePath) {
        $this.Repositories = $repositories
        $this.SelectedIndex = 0
        $this.PreviousIndex = 0
        $this.IsRunning = $true
        $this.ExitState = "None"
        $this.RequiresFullRedraw = $false
        $this.SelectionChanged = $false
        
        # Initialize paging defaults
        $this.ViewportStart = 0
        $this.ViewportChanged = $false
        
        # Initialize navigation stack for hierarchical navigation
        $this.NavigationStack = [System.Collections.Generic.Stack[hashtable]]::new()
        $this.CurrentPath = $basePath
        $this.BasePath = $basePath
        
        # Create WindowSizeCalculator for size calculations
        $this.WindowCalculator = [WindowSizeCalculator]::new()
        $this.PageSize = $this.WindowCalculator.CalculateInitialPageSize()
    }
    
    #region Navigation Methods
    
    <#
    .SYNOPSIS
        Moves selection to the next repository (with wraparound and scrolling)
    #>
    [void] SelectNext() {
        $this.PreviousIndex = $this.SelectedIndex
        $total = $this.Repositories.Count
        
        if ($this.SelectedIndex -lt ($total - 1)) {
            $this.SelectedIndex++
            
            # Scroll down check
            # If SelectedIndex is outside visible range [Start, Start+PageSize-1]
            if ($this.SelectedIndex -ge ($this.ViewportStart + $this.PageSize)) {
                # Move viewport so SelectedIndex is the LAST item
                $this.ViewportStart = $this.SelectedIndex - $this.PageSize + 1
                $this.ViewportChanged = $true
            }
        } else {
            # Wraparound to top
            $this.SelectedIndex = 0
            if ($this.ViewportStart -ne 0) {
                $this.ViewportStart = 0
                $this.ViewportChanged = $true
            }
        }
        $this.SelectionChanged = $true
    }
    
    <#
    .SYNOPSIS
        Moves selection to the previous repository (with wraparound and scrolling)
    #>
    [void] SelectPrevious() {
        $this.PreviousIndex = $this.SelectedIndex
        $total = $this.Repositories.Count
        
        if ($this.SelectedIndex -gt 0) {
            $this.SelectedIndex--
            
            # Scroll up check
            # If SelectedIndex is before Start
            if ($this.SelectedIndex -lt $this.ViewportStart) {
                $this.ViewportStart = $this.SelectedIndex
                $this.ViewportChanged = $true
            }
        } else {
            # Wraparound to bottom
            $this.SelectedIndex = $total - 1
            
            # Adjust viewport to show last item
            # We want SelectedIndex to be visible. 
            # Ideally at the bottom of the page if possible.
            $newViewport = [Math]::Max(0, $total - $this.PageSize)
            if ($this.ViewportStart -ne $newViewport) {
                $this.ViewportStart = $newViewport
                $this.ViewportChanged = $true
            }
        }
        $this.SelectionChanged = $true
    }
    
    <#
    .SYNOPSIS
        Moves selection to a specific index
    #>
    [void] SelectIndex([int]$index) {
        if ($index -ge 0 -and $index -lt $this.Repositories.Count) {
             $this.PreviousIndex = $this.SelectedIndex
             $this.SelectedIndex = $index
             
             # Adjust viewport to ensure index is visible
             if ($index -lt $this.ViewportStart) {
                 $this.ViewportStart = $index
                 $this.ViewportChanged = $true
             }
             elseif ($index -ge ($this.ViewportStart + $this.PageSize)) {
                 $this.ViewportStart = [Math]::Max(0, $index - $this.PageSize + 1)
                 $this.ViewportChanged = $true
             }
             
             $this.SelectionChanged = $true
        }
    }
    
    #endregion
    
    #region State Management
    
    <#
    .SYNOPSIS
        Stops the navigation loop
    #>
    [void] Stop() {
        $this.IsRunning = $false
    }
    
    <#
    .SYNOPSIS
        Gets the currently selected repository
    #>
    [object] GetSelectedRepository() {
        if ($this.Repositories.Count -eq 0) {
            return $null
        }
        return $this.Repositories[$this.SelectedIndex]
    }
    
    <#
    .SYNOPSIS
        Gets the previously selected repository
    #>
    [object] GetPreviousRepository() {
        if ($this.Repositories.Count -eq 0) {
            return $null
        }
        return $this.Repositories[$this.PreviousIndex]
    }
    
    <#
    .SYNOPSIS
        Updates the repository list (e.g., after clone/delete/refresh)
    #>
    [void] UpdateRepositories([array]$repositories) {
        $this.Repositories = $repositories
        
        # Adjust index if it's out of bounds
        if ($this.SelectedIndex -ge $repositories.Count) {
            $this.SelectedIndex = [Math]::Max(0, $repositories.Count - 1)
        }
    }
    
    <#
    .SYNOPSIS
        Finds the index of a repository by name (useful after resorting)
    #>
    [int] FindRepositoryIndex([string]$repoName) {
        for ($i = 0; $i -lt $this.Repositories.Count; $i++) {
            if ($this.Repositories[$i].Name -eq $repoName) {
                return $i
            }
        }
        return 0  # Default to first if not found
    }
    
    #endregion
    
    #region Rendering Flags (Dirty Flag Pattern)
    
    <#
    .SYNOPSIS
        Marks that a full screen redraw is needed
    #>
    [void] MarkForFullRedraw() {
        $this.RequiresFullRedraw = $true
        $this.SelectionChanged = $false
    }
    
    <#
    .SYNOPSIS
        Marks that only affected items need redrawing
    #>
    [void] MarkForPartialRedraw() {
        if (-not $this.RequiresFullRedraw) {
            $this.SelectionChanged = $true
        }
    }
    
    <#
    .SYNOPSIS
        Clears all redraw flags after rendering
    #>
    [void] ClearRedrawFlags() {
        $this.RequiresFullRedraw = $false
        $this.SelectionChanged = $false
    }
    
    <#
    .SYNOPSIS
        Clears the full redraw flag
    #>
    [void] ClearFullRedrawFlag() {
        $this.RequiresFullRedraw = $false
    }
    
    <#
    .SYNOPSIS
        Clears the selection changed flag
    #>
    [void] ClearSelectionChangedFlag() {
        $this.SelectionChanged = $false
    }
    
    <#
    .SYNOPSIS
        Checks if a full redraw is needed
    #>
    [bool] NeedsFullRedraw() {
        return $this.RequiresFullRedraw
    }
    
    <#
    .SYNOPSIS
        Checks if selection has changed
    #>
    [bool] HasSelectionChanged() {
        return $this.SelectionChanged
    }
    
    <#
    .SYNOPSIS
        Checks if any redrawing is needed
    #>
    [bool] NeedsRedraw() {
        return $this.RequiresFullRedraw -or $this.SelectionChanged
    }
    
    #endregion
    
    #region Exit State Management
    
    <#
    .SYNOPSIS
        Sets the exit state
    #>
    [void] SetExitState([string]$exitState) {
        $this.ExitState = $exitState
    }
    
    <#
    .SYNOPSIS
        Gets the exit state
    #>
    [string] GetExitState() {
        return $this.ExitState
    }
    
    <#
    .SYNOPSIS
        Checks if the loop should exit
    #>
    [bool] ShouldExit() {
        return -not $this.IsRunning
    }
    
    <#
    .SYNOPSIS
        Resumes the navigation loop (used after interactive commands)
    #>
    [void] Resume() {
        $this.IsRunning = $true
    }
    
    #endregion
    
    #region Getters and Setters (for compatibility with commands)
    
    <#
    .SYNOPSIS
        Gets current repositories array
    #>
    [array] GetRepositories() {
        return $this.Repositories
    }
    
    <#
    .SYNOPSIS
        Sets repositories array
    #>
    [void] SetRepositories([array]$repositories) {
        $this.Repositories = $repositories
        
        # Adjust index if it's out of bounds
        if ($this.SelectedIndex -ge $repositories.Count -and $repositories.Count -gt 0) {
            $this.SelectedIndex = $repositories.Count - 1
        }
        elseif ($repositories.Count -eq 0) {
            $this.SelectedIndex = 0
        }
    }
    
    <#
    .SYNOPSIS
        Gets current index
    #>
    [int] GetCurrentIndex() {
        return $this.SelectedIndex
    }
    
    <#
    .SYNOPSIS
        Sets current index
    #>
    [void] SetCurrentIndex([int]$index) {
        if ($index -ge 0 -and $index -lt $this.Repositories.Count) {
            $this.PreviousIndex = $this.SelectedIndex
            $this.SelectedIndex = $index
            $this.SelectionChanged = $true
        }
    }
    
    <#
    .SYNOPSIS
        Gets previous index
    #>
    [int] GetPreviousIndex() {
        return $this.PreviousIndex
    }
    
    <#
    .SYNOPSIS
        Check and update window size dynamically (delegates to WindowSizeCalculator)
    #>
    [void] UpdateWindowSize([int]$headerHeight) {
        $newPageSize = $this.WindowCalculator.CalculatePageSize($headerHeight)
        
        if ($this.PageSize -ne $newPageSize) {
            $this.PageSize = $newPageSize
            $this.RequiresFullRedraw = $true
            
            # Adjust viewport to keep selected item visible
            $this.ViewportStart = $this.WindowCalculator.AdjustViewportForSelection(
                $this.SelectedIndex, 
                $this.ViewportStart, 
                $this.PageSize
            )
        }
    }

    #endregion
    
    #region Statistics
    
    <#
    .SYNOPSIS
        Gets the total number of repositories
    #>
    [int] GetTotalCount() {
        return $this.Repositories.Count
    }
    
    <#
    .SYNOPSIS
        Gets the count of repositories with loaded git status (excludes containers)
    #>
    [int] GetLoadedCount() {
        $loaded = $this.Repositories | Where-Object { -not $_.IsContainer -and $_.HasGitStatusLoaded() }
        return ($loaded | Measure-Object | Select-Object -ExpandProperty Count)
    }
    
    <#
    .SYNOPSIS
        Gets the count of actual repositories (excludes containers)
    #>
    [int] GetRepoCount() {
        $repos = $this.Repositories | Where-Object { -not $_.IsContainer }
        return ($repos | Measure-Object | Select-Object -ExpandProperty Count)
    }
    
    #endregion
    
    #region Hierarchical Navigation (Container Folders)
    
    <#
    .SYNOPSIS
        Enters a container folder, saving current state to stack
    #>
    [void] EnterContainer([string]$containerPath, [array]$newRepositories) {
        # Save current state to stack
        $currentState = @{
            Repositories = $this.Repositories
            SelectedIndex = $this.SelectedIndex
            ViewportStart = $this.ViewportStart
            Path = $this.CurrentPath
        }
        $this.NavigationStack.Push($currentState)
        
        # Update to new container state
        $this.Repositories = $newRepositories
        $this.SelectedIndex = 0
        $this.PreviousIndex = 0
        $this.ViewportStart = 0
        $this.CurrentPath = $containerPath
        
        # Mark for full redraw
        $this.RequiresFullRedraw = $true
    }
    
    <#
    .SYNOPSIS
        Goes back to previous navigation level
    .RETURNS
        $true if went back, $false if already at root
    #>
    [bool] GoBack() {
        if ($this.NavigationStack.Count -eq 0) {
            return $false
        }
        
        # Restore previous state from stack
        $previousState = $this.NavigationStack.Pop()
        $this.Repositories = $previousState.Repositories
        $this.SelectedIndex = $previousState.SelectedIndex
        $this.PreviousIndex = $previousState.SelectedIndex
        $this.ViewportStart = $previousState.ViewportStart
        $this.CurrentPath = $previousState.Path
        
        # Mark for full redraw
        $this.RequiresFullRedraw = $true
        
        return $true
    }
    
    <#
    .SYNOPSIS
        Checks if we can go back (not at root level)
    #>
    [bool] CanGoBack() {
        return $this.NavigationStack.Count -gt 0
    }
    
    <#
    .SYNOPSIS
        Gets the current navigation depth (0 = root)
    #>
    [int] GetNavigationDepth() {
        return $this.NavigationStack.Count
    }
    
    <#
    .SYNOPSIS
        Gets the current path for display (breadcrumb)
    #>
    [string] GetBreadcrumb() {
        if ([string]::IsNullOrEmpty($this.BasePath) -or [string]::IsNullOrEmpty($this.CurrentPath)) {
            return ""
        }
        
        if ($this.CurrentPath -eq $this.BasePath) {
            return ""
        }
        
        # Get relative path from base
        $relativePath = $this.CurrentPath.Substring($this.BasePath.Length).TrimStart('\', '/')
        return $relativePath
    }
    
    <#
    .SYNOPSIS
        Gets the parent path from the navigation stack (if inside a container)
    #>
    [string] GetParentPath() {
        if ($this.NavigationStack.Count -eq 0) {
            return $null
        }
        $parentEntry = $this.NavigationStack.Peek()
        return $parentEntry.Path
    }
    
    <#
    .SYNOPSIS
        Checks if currently inside a container (not at base level)
    #>
    [bool] IsInsideContainer() {
        # Safety check for null values
        if ([string]::IsNullOrEmpty($this.CurrentPath) -or [string]::IsNullOrEmpty($this.BasePath)) {
            return $false
        }
        return $this.CurrentPath -ne $this.BasePath
    }
    
    <#
    .SYNOPSIS
        Gets the current path
    #>
    [string] GetCurrentPath() {
        return $this.CurrentPath
    }
    
    <#
    .SYNOPSIS
        Sets the current path
    #>
    [void] SetCurrentPath([string]$path) {
        $this.CurrentPath = $path
    }
    
    <#
    .SYNOPSIS
        Sets the base path
    #>
    [void] SetBasePath([string]$path) {
        $this.BasePath = $path
        if ([string]::IsNullOrEmpty($this.CurrentPath)) {
            $this.CurrentPath = $path
        }
    }
    
    #endregion
}
