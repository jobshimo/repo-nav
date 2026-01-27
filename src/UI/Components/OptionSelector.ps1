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

    .PARAMETER ShowCurrentMarker
        Whether to append "(current)" text to the currently selected item (default: $true)

    .PARAMETER Description
        Optional text to display below the header (default: empty)
    
    .RETURNS
        Selected option value, or $null if cancelled
    #>
    # Overload for backward compatibility (4 arguments)
    [object] ShowSelection([string]$title, [array]$options, [object]$currentValue, [string]$cancelText) {
        return $this.ShowSelection($title, $options, $currentValue, $cancelText, $true, "", $true)
    }

    # Main method with all options
    [object] ShowSelection([string]$title, [array]$options, [object]$currentValue, [string]$cancelText, [bool]$showCurrentMarker, [string]$description, [bool]$clearScreen = $true) {
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
            
            # Clear screen once and render header
            # Clear screen once and render header
            if ($clearScreen) {
                $this.Console.ClearScreen()
            }
            $this.Renderer.RenderHeader($title)
            
            # If headers are hidden, we must still show the "Title" (Prompt/Question) 
            # as part of the content body
            $preferences = $this.Renderer.PreferencesService.LoadPreferences()
            $showHeaders = if ($preferences.display.PSObject.Properties.Name -contains 'showHeaders') { $preferences.display.showHeaders } else { $true }
            
            if (-not $showHeaders) {
                # Render prompt as high-visibility content
                $this.Console.WriteLineColored("  $title", [Constants]::ColorHighlight)
                $this.Console.WriteSeparator("-", [Constants]::UIWidth, [Constants]::ColorSeparator)
            }
            
            $this.Console.NewLine()
            
            if (-not [string]::IsNullOrWhiteSpace($description)) {
                $this.Console.WriteLineColored("  $description", [Constants]::ColorWarning)
                $this.Console.NewLine()
            }
            
            # Store the starting position of the list to avoid full screen clears
            $listStartTop = $this.Console.GetCursorTop()
            
            while ($running) {
                # Reset cursor to the start of the list
                $this.Console.SetCursorPosition(0, $listStartTop)

                # Display options
                for ($i = 0; $i -lt $options.Count; $i++) {
                    $option = $options[$i]
                    $prefix = if ($i -eq $selectedIndex) { ">" } else { " " }
                    $color = if ($i -eq $selectedIndex) { [Constants]::ColorSelected } else { [Constants]::ColorMenuText }
                    
                    # Add indicator if this is the current value
                    $currentMarker = if ($showCurrentMarker -and $option.Value -eq $currentValue) { " (current)" } else { "" }
                    
                    $displayLine = "  $prefix $($option.DisplayText)$currentMarker"
                    
                    # Attempt to render background color preview if the option value is a valid console color
                    # But not if it's 'None'
                    $isColorPreview = $false
                    if ($option.Value -ne 'None' -and ($option.Value -as [System.ConsoleColor])) {
                        $isColorPreview = $true
                    }

                    if ($isColorPreview) {
                        # Show color preview
                        $this.Console.WriteLineColored($displayLine, $option.Value)
                    } else {
                        $this.Console.WriteLineColored($displayLine, $color)
                    }
                }
                
                $this.Console.NewLine()
                $this.Console.WriteLineColored("  $cancelText", [Constants]::ColorHint)
                $this.Console.NewLine()
                $this.Console.WriteLineColored("  Use Arrows to navigate | Enter to select | Q/Esc to cancel", [Constants]::ColorHint)
                
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
            # Ensure cursor remains hidden when returning to main UI
            # (Unless explicitly expecting input next, but the main loop handles that)
            $this.Console.HideCursor()
        }
        
        return $result
    }
    
    <#
    .SYNOPSIS
        Show a simple Yes/No confirmation dialog
    
    .PARAMETER question
        The question to ask
        
    .PARAMETER localizationService
        Optional LocalizationService for translated texts
    
    .RETURNS
        $true if Yes selected, $false if No or cancelled
    #>
    [bool] SelectYesNo([string]$question, [object]$localizationService) {
        # Get localized texts or use defaults
        $yesText = "Yes"
        $noText = "No"
        $cancelText = "Cancel"
        
        if ($null -ne $localizationService) {
            $yesText = $localizationService.Get("Prompt.Yes")
            $noText = $localizationService.Get("Prompt.No")
            $cancelText = $localizationService.Get("Prompt.Cancel")
        }
        
        $options = @(
            @{ DisplayText = $yesText; Value = $true },
            @{ DisplayText = $noText; Value = $false }
        )
        
        $result = $this.ShowSelection($question, $options, $false, $cancelText, $false, "")
        
        if ($null -eq $result) {
            return $false
        }
        
        return $result
    }
    
    # Overload without localization for backward compatibility
    [bool] SelectYesNo([string]$question) {
        return $this.SelectYesNo($question, $null)
    }
}
