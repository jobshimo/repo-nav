<#
.SYNOPSIS
    ViewportManager - Reusable viewport/pagination logic for list navigation.
    
.DESCRIPTION
    Extracts common viewport logic used in OptionSelector, SearchView, and PreferencesMenuController.
    Following SOLID principles:
    - SRP: Only handles viewport calculations
    - Reusable across all scrolling lists
#>

class ViewportManager {
    [int] $ViewportStart = 0
    [int] $SelectedIndex = 0
    [int] $PageSize = 10
    [int] $TotalItems = 0
    
    ViewportManager() {}
    
    ViewportManager([int]$pageSize) {
        $this.PageSize = $pageSize
    }
    
    # Initialize or reset the viewport
    [void] Initialize([int]$totalItems, [int]$pageSize, [int]$selectedIndex) {
        $this.TotalItems = $totalItems
        $this.PageSize = [Math]::Max(1, $pageSize)
        $this.SelectedIndex = [Math]::Max(0, [Math]::Min($selectedIndex, $totalItems - 1))
        $this.EnsureSelectedVisible()
    }
    
    # Update when page size changes (e.g., window resize)
    [void] SetPageSize([int]$newPageSize) {
        $this.PageSize = [Math]::Max(1, $newPageSize)
        $this.EnsureSelectedVisible()
    }
    
    # Navigate up (returns true if position changed)
    [bool] MoveUp() {
        if ($this.TotalItems -eq 0) { return $false }
        
        if ($this.SelectedIndex -gt 0) {
            $this.SelectedIndex--
        } else {
            # Wrap to bottom
            $this.SelectedIndex = $this.TotalItems - 1
        }
        $this.EnsureSelectedVisible()
        return $true
    }
    
    # Navigate down (returns true if position changed)
    [bool] MoveDown() {
        if ($this.TotalItems -eq 0) { return $false }
        
        if ($this.SelectedIndex -lt ($this.TotalItems - 1)) {
            $this.SelectedIndex++
        } else {
            # Wrap to top
            $this.SelectedIndex = 0
        }
        $this.EnsureSelectedVisible()
        return $true
    }
    
    # Jump to start
    [void] MoveToStart() {
        $this.SelectedIndex = 0
        $this.ViewportStart = 0
    }
    
    # Jump to end
    [void] MoveToEnd() {
        if ($this.TotalItems -eq 0) { return }
        $this.SelectedIndex = $this.TotalItems - 1
        $this.EnsureSelectedVisible()
    }
    
    # Page up (move by pageSize)
    [bool] PageUp() {
        if ($this.TotalItems -eq 0) { return $false }
        $this.SelectedIndex = [Math]::Max(0, $this.SelectedIndex - $this.PageSize)
        $this.EnsureSelectedVisible()
        return $true
    }
    
    # Page down (move by pageSize)
    [bool] PageDown() {
        if ($this.TotalItems -eq 0) { return $false }
        $this.SelectedIndex = [Math]::Min($this.TotalItems - 1, $this.SelectedIndex + $this.PageSize)
        $this.EnsureSelectedVisible()
        return $true
    }
    
    # Get visible range for rendering
    [hashtable] GetVisibleRange() {
        return @{
            Start = $this.ViewportStart
            End = [Math]::Min($this.ViewportStart + $this.PageSize, $this.TotalItems)
            PageSize = $this.PageSize
            SelectedIndex = $this.SelectedIndex
            TotalItems = $this.TotalItems
        }
    }
    
    # Check if an index is visible in current viewport
    [bool] IsVisible([int]$index) {
        return ($index -ge $this.ViewportStart) -and ($index -lt ($this.ViewportStart + $this.PageSize))
    }
    
    # Ensure selected item is visible (scroll if needed)
    [void] hidden EnsureSelectedVisible() {
        if ($this.SelectedIndex -lt $this.ViewportStart) {
            $this.ViewportStart = $this.SelectedIndex
        }
        elseif ($this.SelectedIndex -ge ($this.ViewportStart + $this.PageSize)) {
            $this.ViewportStart = $this.SelectedIndex - $this.PageSize + 1
        }
        
        # Ensure viewport doesn't go negative
        $this.ViewportStart = [Math]::Max(0, $this.ViewportStart)
        
        # Ensure viewport doesn't exceed bounds
        $maxStart = [Math]::Max(0, $this.TotalItems - $this.PageSize)
        $this.ViewportStart = [Math]::Min($this.ViewportStart, $maxStart)
    }
    
    # Reset viewport to initial state
    [void] Reset() {
        $this.ViewportStart = 0
        $this.SelectedIndex = 0
    }
}
