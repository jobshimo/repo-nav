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
    - SRP: Only manages navigation state
    - OCP: Can be extended with new state properties
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
    
    # Rendering optimization flags
    [bool] $RequiresFullRedraw
    [bool] $SelectionChanged
    [int] $PreviousIndex
    
    # Constructor
    NavigationState([array]$repositories) {
        $this.Repositories = $repositories
        $this.SelectedIndex = 0
        $this.PreviousIndex = 0
        $this.IsRunning = $true
        $this.ExitState = "None"
        $this.RequiresFullRedraw = $false
        $this.SelectionChanged = $false
    }
    
    #region Navigation Methods
    
    <#
    .SYNOPSIS
        Moves selection to the next repository (with wraparound)
    #>
    [void] SelectNext() {
        $this.PreviousIndex = $this.SelectedIndex
        
        if ($this.SelectedIndex -lt ($this.Repositories.Count - 1)) {
            $this.SelectedIndex++
        } else {
            $this.SelectedIndex = 0
        }
    }
    
    <#
    .SYNOPSIS
        Moves selection to the previous repository (with wraparound)
    #>
    [void] SelectPrevious() {
        $this.PreviousIndex = $this.SelectedIndex
        
        if ($this.SelectedIndex -gt 0) {
            $this.SelectedIndex--
        } else {
            $this.SelectedIndex = $this.Repositories.Count - 1
        }
    }
    
    <#
    .SYNOPSIS
        Moves selection to a specific index
    #>
    [void] SelectIndex([int]$index) {
        if ($index -ge 0 -and $index -lt $this.Repositories.Count) {
            $this.PreviousIndex = $this.SelectedIndex
            $this.SelectedIndex = $index
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
        Gets the count of repositories with loaded git status
    #>
    [int] GetLoadedCount() {
        $loaded = $this.Repositories | Where-Object { $_.HasGitStatusLoaded() }
        return ($loaded | Measure-Object | Select-Object -ExpandProperty Count)
    }
    
    #endregion
}
