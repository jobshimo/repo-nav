<#
.SYNOPSIS
    WindowSizeCalculator - Calculates UI dimensions based on console window size
    
.DESCRIPTION
    Following SOLID principles:
    - SRP: Only responsible for window/viewport size calculations
    - DIP: Provides abstraction for window size operations
    
    Extracted from NavigationState to separate UI concerns from state management.
#>

class WindowSizeCalculator {
    # Configuration
    [int] $MinPageSize = 1
    [int] $MaxPageSize = 50 # Increased from 25 to maximize use of screen space
    [int] $DefaultPageSize = 15
    [int] $FooterAndSafetyLines = 7  # Footer(4) + Gap(1) + Safety(2)
    
    <#
    .SYNOPSIS
        Calculates the optimal page size based on current window height
        
    .PARAMETER headerHeight
        The height of the header/menu area in lines
        
    .RETURNS
        The calculated page size (number of items that can be displayed)
    #>
    [int] CalculatePageSize([int]$headerHeight) {
        try {
            $windowHeight = $global:Host.UI.RawUI.WindowSize.Height
            $reservedLines = $headerHeight + $this.FooterAndSafetyLines
            $calculatedSize = $windowHeight - $reservedLines
            
            # Apply bounds
            if ($calculatedSize -lt $this.MinPageSize) { 
                return $this.MinPageSize 
            }
            if ($calculatedSize -gt $this.MaxPageSize) { 
                return $this.MaxPageSize 
            }
            
            return $calculatedSize
        }
        catch {
            # Fallback if host doesn't support WindowSize
            return $this.DefaultPageSize
        }
    }
    
    <#
    .SYNOPSIS
        Gets the current window height
        
    .RETURNS
        Window height in lines, or default value if unavailable
    #>
    [int] GetWindowHeight() {
        try {
            return $global:Host.UI.RawUI.WindowSize.Height
        }
        catch {
            return 30  # Default fallback
        }
    }
    
    <#
    .SYNOPSIS
        Gets the current window width
        
    .RETURNS
        Window width in characters, or default value if unavailable
    #>
    [int] GetWindowWidth() {
        try {
            return $global:Host.UI.RawUI.WindowSize.Width
        }
        catch {
            return 120  # Default fallback
        }
    }
    
    <#
    .SYNOPSIS
        Calculates initial page size for constructor (with reserved lines estimate)
        
    .RETURNS
        Initial page size based on estimated header
    #>
    [int] CalculateInitialPageSize() {
        # Estimate: Header (~10) + this class's safety = 20 reserved
        $estimatedReserved = 20
        
        try {
            $windowHeight = $global:Host.UI.RawUI.WindowSize.Height
            $availableLines = $windowHeight - $estimatedReserved
            
            if ($availableLines -lt $this.MinPageSize) { 
                return $this.MinPageSize 
            }
            if ($availableLines -gt $this.MaxPageSize) { 
                return $this.MaxPageSize 
            }
            
            return $availableLines
        }
        catch {
            return $this.DefaultPageSize
        }
    }
    
    <#
    .SYNOPSIS
        Adjusts viewport start position to keep selected item visible
        
    .PARAMETER selectedIndex
        Currently selected item index
        
    .PARAMETER viewportStart
        Current viewport start position
        
    .PARAMETER pageSize
        Current page size
        
    .RETURNS
        Adjusted viewport start position
    #>
    [int] AdjustViewportForSelection([int]$selectedIndex, [int]$viewportStart, [int]$pageSize) {
        if ($selectedIndex -lt $viewportStart) {
            return $selectedIndex
        }
        elseif ($selectedIndex -ge ($viewportStart + $pageSize)) {
            return [Math]::Max(0, $selectedIndex - $pageSize + 1)
        }
        return $viewportStart
    }
}
