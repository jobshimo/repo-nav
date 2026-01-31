<#
.SYNOPSIS
    ColorSelector - Interactive color selection UI
    
.DESCRIPTION
    Following SOLID principles:
    - SRP: Only responsible for color selection interaction
    - DIP: Depends on UIRenderer and ConsoleHelper
    - OCP: Can be extended for different selection UIs
    
    Provides interactive color selection with arrow keys
#>

class ColorSelector {
    [IUIRenderer] $Renderer
    [ConsoleHelper] $Console
    [OptionSelector] $OptionSelector
    
    # Constructor with dependency injection
    ColorSelector([IUIRenderer]$renderer, [ConsoleHelper]$console, [OptionSelector]$optionSelector) {
        $this.Renderer = $renderer
        $this.Console = $console
        $this.OptionSelector = $optionSelector
    }
    
    # Show color selection menu and return selected color
    [string] SelectColor([string]$currentColor) {
        $colors = [ColorPalette]::GetAvailableColors()
        
        $options = @()
        foreach ($c in $colors) {
            # OptionSelector has built-in logic to preview colors if the Value is a ConsoleColor
            # or a string that can cast to ConsoleColor.
            $options += @{ Value = $c; DisplayText = $c }
        }
        
        $config = [SelectionOptions]::new()
        $config.Title = $this.Renderer.GetLoc("Selector.Title.Color", "SELECT ALIAS COLOR")
        $config.Options = $options
        $config.CurrentValue = $currentColor
        $config.ShowCurrentMarker = $false # Colors are self-evident
        $config.CancelText = "Keep Current"
        $config.ClearScreen = $true
        $config.Description = $this.Renderer.GetLoc("Selector.Hint.Arrows", "Use arrows to navigate | Enter to select")
        
        $result = $this.OptionSelector.Show($config)
        
        if ($null -eq $result) {
            return $currentColor
        }
        
        return $result
    }
}
