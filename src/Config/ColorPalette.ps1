<#
.SYNOPSIS
    ColorPalette class - Manages color schemes and validation
    
.DESCRIPTION
    Following SRP (Single Responsibility Principle):
    This class only manages colors and provides validation.
#>

class ColorPalette {
    # Available colors for aliases
    static [string[]] $AvailableColors = @(
        'Cyan', 'Yellow', 'Green', 'Magenta', 'Red', 'Blue', 
        'White', 'DarkYellow', 'DarkGreen', 'DarkCyan'
    )
    
    static [string] $DefaultAliasColor = "Cyan"
    
    # Color validation
    static [bool] IsValidColor([string]$color) {
        if ([string]::IsNullOrWhiteSpace($color)) {
            return $false
        }
        return [ColorPalette]::AvailableColors -contains $color
    }
    
    # Get color or default if invalid
    static [string] GetColorOrDefault([string]$color) {
        if ([string]::IsNullOrWhiteSpace($color)) {
            return [ColorPalette]::DefaultAliasColor
        }
        if ([ColorPalette]::IsValidColor($color)) {
            return $color
        }
        return [ColorPalette]::DefaultAliasColor
    }
    
    # Get all available colors
    static [string[]] GetAvailableColors() {
        return [ColorPalette]::AvailableColors
    }
}
