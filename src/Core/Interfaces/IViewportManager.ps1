<#
.SYNOPSIS
    IViewportManager - Interface for viewport/pagination logic
    
.DESCRIPTION
    Abstraction for viewport calculations following DIP.
    Used for list navigation and scrolling.
#>

class IViewportManager {
    # Initialize or reset the viewport
    [void] Initialize([int]$totalItems, [int]$pageSize, [int]$selectedIndex) {
        throw "Not Implemented: Initialize must be overridden"
    }
    
    # Update when page size changes
    [void] SetPageSize([int]$newPageSize) {
        throw "Not Implemented: SetPageSize must be overridden"
    }
    
    # Navigate up (returns true if position changed)
    [bool] MoveUp() {
        throw "Not Implemented: MoveUp must be overridden"
    }
    
    # Navigate down (returns true if position changed)
    [bool] MoveDown() {
        throw "Not Implemented: MoveDown must be overridden"
    }
    
    # Jump to first item
    [void] JumpToFirst() {
        throw "Not Implemented: JumpToFirst must be overridden"
    }
    
    # Jump to last item
    [void] JumpToLast() {
        throw "Not Implemented: JumpToLast must be overridden"
    }
    
    # Get current viewport window
    [PSCustomObject] GetViewportWindow() {
        throw "Not Implemented: GetViewportWindow must be overridden"
    }
}
