<#
.SYNOPSIS
    OptionSelector - Reusable component for selecting from multiple options
    
.DESCRIPTION
    Following SOLID principles:
    - SRP: Only responsible for displaying and selecting from a list of options
    - OCP: Open for extension (can handle any type of options)
    - ISP: Focused interface for option selection
    - DIP: Depends on Console and Renderer abstractions
    
    This component provides:
    - Display of multiple options in a list
    - Navigation with arrow keys
    - Selection with Enter
    - Cancel with Esc/Q
#>

class OptionSelector {
    [ConsoleHelper] $Console
    [UIRenderer] $Renderer
    
    # Constructor with dependency injection
    # Breaking cyclical dependency typing in constructor by using [object]
    OptionSelector([ConsoleHelper]$console, [object]$renderer) {
        $this.Console = $console
        $this.Renderer = $renderer
    }
    
    <#
    .SYNOPSIS
        Show a selection menu and return the selected option
    
    .PARAMETER Title
        Title to display at the top
    
    .PARAMETER Options
        Array of option objects with DisplayText and Value properties
        Example: @(
            @{ DisplayText = "Option 1"; Value = "value1" },
            @{ DisplayText = "Option 2"; Value = "value2" }
        )
    
    .PARAMETER CurrentValue
        The currently selected value (will be highlighted)
    
    .PARAMETER CancelText
        Text to show for the cancel option (default: "Cancel")
    
    .RETURNS
        Selected option value, or $null if cancelled
    #>
    [object] ShowSelection([string]$title, [array]$options, [object]$currentValue, [string]$cancelText = "Cancel") {
        if ($options.Count -eq 0) {
            return $null
        }
        
        # Find current option index
        $selectedIndex = 0
        for ($i = 0; $i -lt $options.Count; $i++) {
            if ($options[$i].Value -eq $currentValue) {
                $selectedIndex = $i
                break
            }
        }
        
        $running = $true
        $result = $null
        
        try {
            $this.Console.HideCursor()
            
            while ($running) {
                # Clear and render
                $this.Console.ClearScreen()
                $this.Renderer.RenderHeader($title)
                Write-Host ""
                
                # Display options
                for ($i = 0; $i -lt $options.Count; $i++) {
                    $option = $options[$i]
                    $prefix = if ($i -eq $selectedIndex) { ">" } else { " " }
                    $color = if ($i -eq $selectedIndex) { [Constants]::ColorSelected } else { [Constants]::ColorMenuText }
                    
                    # Add indicator if this is the current value
                    $currentMarker = if ($option.Value -eq $currentValue) { " (current)" } else { "" }
                    
                    $displayLine = "  $prefix $($option.DisplayText)$currentMarker"
                    
                    # Attempt to render background color preview if the option value is a valid console color
                    # But not if it's 'None'
                    $isColorPreview = $false
                    if ($option.Value -ne 'None' -and ($option.Value -as [System.ConsoleColor])) {
                        $isColorPreview = $true
                    }

                    if ($isColorPreview) {
                        # Show color preview
                        Write-Host $displayLine -ForegroundColor $option.Value
                    } else {
                        Write-Host $displayLine -ForegroundColor $color
                    }
                }
                
                Write-Host ""
                Write-Host "  $cancelText" -ForegroundColor ([Constants]::ColorHint)
                Write-Host ""
                Write-Host "  Use Arrows to navigate | Enter to select | Q/Esc to cancel" -ForegroundColor ([Constants]::ColorHint)
                
                # Wait for input
                $key = $this.Console.ReadKey()
                
                switch ($key.VirtualKeyCode) {
                    ([Constants]::KEY_UP_ARROW) {
                        if ($selectedIndex -gt 0) {
                            $selectedIndex--
                        } else {
                            $selectedIndex = $options.Count - 1
                        }
                    }
                    
                    ([Constants]::KEY_DOWN_ARROW) {
                        if ($selectedIndex -lt ($options.Count - 1)) {
                            $selectedIndex++
                        } else {
                            $selectedIndex = 0
                        }
                    }
                    
                    ([Constants]::KEY_ENTER) {
                        $result = $options[$selectedIndex].Value
                        $running = $false
                    }
                    
                    ([Constants]::KEY_Q) {
                        $running = $false
                    }
                    
                    ([Constants]::KEY_ESC) {
                        $running = $false
                    }
                }
            }
        }
        finally {
            $this.Console.ShowCursor()
        }
        
        return $result
    }
}
