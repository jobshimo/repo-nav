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
    [UIRenderer] $Renderer
    [ConsoleHelper] $Console
    
    # Constructor with dependency injection
    ColorSelector([UIRenderer]$renderer, [ConsoleHelper]$console) {
        $this.Renderer = $renderer
        $this.Console = $console
    }
    
    # Show color selection menu and return selected color
    [string] SelectColor([string]$currentColor) {
        $colors = [ColorPalette]::GetAvailableColors()
        
        # Find index of current color
        $selectedIndex = 0
        for ($i = 0; $i -lt $colors.Count; $i++) {
            if ($colors[$i] -eq $currentColor) {
                $selectedIndex = $i
                break
            }
        }
        
        $previousIndex = -1
        $colorListStartLine = 6  # Header + instruction + blank
        
        try {
            $this.Console.HideCursor()
            
            # Initial render
            $this.Console.ClearScreen()
            $this.Renderer.RenderHeader("SELECT ALIAS COLOR")
            Write-Host ""
            Write-Host "  Use arrows to navigate | Enter to select" -ForegroundColor Gray
            Write-Host ""
            
            for ($i = 0; $i -lt $colors.Count; $i++) {
                $this.Renderer.RenderColorItem($colors[$i], ($i -eq $selectedIndex))
            }
            
            Write-Host ""
            Write-Host ("=" * 55) -ForegroundColor Cyan
            
            $previousIndex = $selectedIndex
            
            # Input loop
            while ($true) {
                $key = $this.Console.ReadKey()
                
                switch ($key.VirtualKeyCode) {
                    ([Constants]::KEY_UP_ARROW) {
                        $previousIndex = $selectedIndex
                        if ($selectedIndex -gt 0) {
                            $selectedIndex--
                        } else {
                            $selectedIndex = $colors.Count - 1
                        }
                        
                        # Update only changed items
                        $this.Renderer.UpdateColorItemAt(($colorListStartLine + $previousIndex), $colors[$previousIndex], $false)
                        $this.Renderer.UpdateColorItemAt(($colorListStartLine + $selectedIndex), $colors[$selectedIndex], $true)
                    }
                    
                    ([Constants]::KEY_DOWN_ARROW) {
                        $previousIndex = $selectedIndex
                        if ($selectedIndex -lt ($colors.Count - 1)) {
                            $selectedIndex++
                        } else {
                            $selectedIndex = 0
                        }
                        
                        # Update only changed items
                        $this.Renderer.UpdateColorItemAt(($colorListStartLine + $previousIndex), $colors[$previousIndex], $false)
                        $this.Renderer.UpdateColorItemAt(($colorListStartLine + $selectedIndex), $colors[$selectedIndex], $true)
                    }
                    
                    ([Constants]::KEY_ENTER) {
                        return $colors[$selectedIndex]
                    }
                    
                    ([Constants]::KEY_ESC) {
                        return $currentColor  # Return unchanged
                    }
                }
            }
        }
        finally {
            $this.Console.ShowCursor()
        }
        
        # This should never be reached, but PowerShell requires it
        return $currentColor
    }
}
