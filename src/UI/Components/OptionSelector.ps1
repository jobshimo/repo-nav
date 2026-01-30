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

class OptionSelector : ConsoleView {
    [UIRenderer] $Renderer
    
    # Constructor with dependency injection
    # Breaking cyclical dependency typing in constructor by using [object]
    OptionSelector([ConsoleHelper]$console, [object]$renderer) : base($console) {
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
        return $this.ShowSelection($title, $options, $currentValue, $cancelText, $true, "", [Constants]::ColorWarning, $true, $null, $null)
    }
    
    # Overload for callback compatibility
    [object] ShowSelection([string]$title, [array]$options, [object]$currentValue, [string]$cancelText, [bool]$showCurrentMarker, [string]$description, [ConsoleColor]$descriptionColor, [bool]$clearScreen, [scriptblock]$onSelectionChanged) {
        return $this.ShowSelection($title, $options, $currentValue, $cancelText, $showCurrentMarker, $description, $descriptionColor, $clearScreen, $onSelectionChanged, $null)
    }

    # Main method with all options
    [object] ShowSelection([string]$title, [array]$options, [object]$currentValue, [string]$cancelText, [bool]$showCurrentMarker, [string]$description, [ConsoleColor]$descriptionColor, [bool]$clearScreen = $true, [scriptblock]$onSelectionChanged = $null, [scriptblock]$onRenderItem = $null) {
        if ($options.Count -eq 0) {
            return $null
        }
        
        # Default color handling
        if ($descriptionColor -eq 0) { $descriptionColor = [Constants]::ColorWarning }
        
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
        $lastSelectedIndex = -1
        
        try {
            $this.Console.HideCursor()
            
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
                $this.WriteLineColored("  $title", [Constants]::ColorHighlight)
                $this.Console.WriteSeparator("-", [Constants]::UIWidth, [Constants]::ColorSeparator)
            }
            
            $this.NewLine()
            
            if (-not [string]::IsNullOrWhiteSpace($description)) {
                $this.WriteLineColored("  $description", $descriptionColor)
                $this.NewLine()
            }
            
            # Store the starting position of the list to avoid full screen clears
            $listStartTop = $this.Console.GetCursorTop()
            
            # Initialize viewport state
            $viewportStart = 0
            # Reserve space for Footer (Safe margin: 6 lines + optional detail space)
            # Structure: Newline, Cancel, Newline, Newline, Hint -> 5 lines + 1 safety
            $reservedFooter = 8 # Increased to allow space for detail
            
            # Force first render logic
            $forceRender = $true

            while ($running) {
                # 0. Handle Selection Change Callback
                if ($selectedIndex -ne $lastSelectedIndex -or $forceRender) {
                    if ($null -ne $onSelectionChanged) {
                         # We invoke this AFTER rendering the list usually, but since the list is windowed,
                         # we can render the detail in the reserved footer area.
                         # But let's let logical update happen first.
                    }
                }

                # 1. Logic (Update Viewport)
                $pageSize = $this.CalculatePageSize($options.Count, $listStartTop, $reservedFooter)
                $viewportStart = $this.CalculateViewportStart($selectedIndex, $viewportStart, $pageSize, $options.Count)

                # 2. Render List
                
                # Reset cursor to the start of the list
                $this.Console.SetCursorPosition(0, $listStartTop)

                # Display options (Windowed)
                for ($i = 0; $i -lt $pageSize; $i++) {
                    $optionIndex = $viewportStart + $i
                    $option = $options[$optionIndex]
                    
                    $isSelected = ($optionIndex -eq $selectedIndex)
                    $prefix = if ($isSelected) { ">" } else { " " }
                    $color = if ($isSelected) { [Constants]::ColorSelected } else { [Constants]::ColorMenuText }
                    
                    # Custom Render Callback
                    if ($null -ne $onRenderItem) {
                        # Invoke custom renderer
                        # Param: Option, IsSelected, Prefix
                        & $onRenderItem $option $isSelected $prefix
                    } else {
                        # Default rendering
                        
                        # Add indicator if this is the current value
                        $currentMarker = if ($showCurrentMarker -and $option.Value -eq $currentValue) { " (current)" } else { "" }
                        
                        $displayLine = "  $prefix $($option.DisplayText)$currentMarker"
                        
                        $isColorPreview = $false
                        if ($option.Value -ne 'None' -and ($option.Value -as [System.ConsoleColor])) {
                            $isColorPreview = $true
                        }

                        # Clear line first to prevent ghosting
                        $this.ClearLine()

                        if ($isColorPreview) {
                            # Show color preview
                            $this.WriteLineColored($displayLine, $option.Value)
                        } else {
                            $this.WriteLineColored($displayLine, $color)
                        }
                    }
                }
                
                # Render Footer (Static)
                $this.NewLine()
                $this.ClearLine()
                $this.WriteLineColored("  $cancelText", [Constants]::ColorHint)
                $this.NewLine()
                
                # Render Detail (Dynamic via Callback)
                # Always render detail to prevent ghosting of footer below it
                if ($null -ne $onSelectionChanged) {
                    $detailStartTop = $this.Console.GetCursorTop()
                    $this.Console.SetCursorPosition(0, $detailStartTop)
                    
                    # Force clear a dedicated area for details (e.g. 1 line)
                    # Ideally the callback handles its own clearing, but we help it here
                    $this.ClearLine()
                    
                    try {
                        & $onSelectionChanged $options[$selectedIndex]
                    } catch {
                        # Ignore errors in callback
                    }
                }
                
                # Render keys hint at the very bottom or fixed position? 
                # Let's put it after the detail area.
                $this.Console.Write("`n`n")
                $this.ClearLine()
                $this.WriteLineColored("  Use Arrows | Enter | Q/Esc", [Constants]::ColorMenuText)
                
                # Clear line below just in case
                $this.NewLine()
                $this.ClearLine()
                $this.Console.SetCursorPosition(0, $this.Console.GetCursorTop() - 1)
                
                $lastSelectedIndex = $selectedIndex
                $forceRender = $false
                
                # 3. Input
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
    [bool] SelectYesNo([string]$question, [object]$localizationService, [bool]$clearScreen = $true) {
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
        
        # Pass clearScreen and default color
        $result = $this.ShowSelection($question, $options, $false, $cancelText, $false, "", [Constants]::ColorWarning, $clearScreen)
        
        if ($null -eq $result) {
            return $false
        }
        
        return $result
    }
    
    # Overload without localization for backward compatibility
    [bool] SelectYesNo([string]$question) {
        return $this.SelectYesNo($question, $null, $true)
    }
    
    # Overload with just clearScreen
    [bool] SelectYesNo([string]$question, [bool]$clearScreen) {
        return $this.SelectYesNo($question, $null, $clearScreen)
    }
}
