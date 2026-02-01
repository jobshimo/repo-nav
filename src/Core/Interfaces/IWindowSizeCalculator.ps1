<#
.SYNOPSIS
    Interface for window size calculations (Abstract Base Class pattern)
    
.DESCRIPTION
    Abstracts the logic for determining UI dimensions. 
    Implements a base class pattern as PowerShell 5.1 does not support native interfaces.
#>
class IWindowSizeCalculator {
    [int] CalculatePageSize([int]$headerHeight) { return 0 }
    [int] GetWindowHeight() { return 0 }
    [int] GetWindowWidth() { return 0 }
    [int] CalculateInitialPageSize() { return 0 }
    [int] AdjustViewportForSelection([int]$selectedIndex, [int]$viewportStart, [int]$pageSize) { return 0 }
}
