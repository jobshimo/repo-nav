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
    
    # Rendering optimization flags
    [bool] $RequiresFullRedraw
    [bool] $RequiresPartialRedraw
    [int] $PreviousIndex
    
    # Constructor
    NavigationState([array]$repositories) {
        $this.Repositories = $repositories
        $this.SelectedIndex = 0
        $this.PreviousIndex = 0
        $this.IsRunning = $true
        $this.RequiresFullRedraw = $false
        $this.RequiresPartialRedraw = $false
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
        $this.RequiresPartialRedraw = $false
    }
    
    <#
    .SYNOPSIS
        Marks that only affected items need redrawing
    #>
    [void] MarkForPartialRedraw() {
        if (-not $this.RequiresFullRedraw) {
            $this.RequiresPartialRedraw = $true
        }
    }
    
    <#
    .SYNOPSIS
        Clears all redraw flags after rendering
    #>
    [void] ClearRedrawFlags() {
        $this.RequiresFullRedraw = $false
        $this.RequiresPartialRedraw = $false
    }
    
    <#
    .SYNOPSIS
        Checks if any redrawing is needed
    #>
    [bool] NeedsRedraw() {
        return $this.RequiresFullRedraw -or $this.RequiresPartialRedraw
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
