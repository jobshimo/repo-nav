<#
.SYNOPSIS
    PreferencesMenuRenderer - Renders the preferences menu.
    
.DESCRIPTION
    Extracted from PreferencesMenuController following SRP:
    - This class ONLY handles rendering
    - PreferencesMenuController handles navigation and orchestration
#>

class PreferencesMenuRenderer {
    [ConsoleHelper] $Console
    [IUIRenderer] $Renderer
    [LocalizationService] $LocalizationService
    
    PreferencesMenuRenderer([ConsoleHelper]$console, [IUIRenderer]$renderer, [LocalizationService]$locService) {
        $this.Console = $console
        $this.Renderer = $renderer
        $this.LocalizationService = $locService
    }
    
    # Render the menu items within the viewport
    [void] RenderMenu([array]$items, [int]$selectedIndex, [int]$startTop, [int]$viewportStart, [int]$pageSize, [scriptblock]$GetLoc) {
        for ($i = 0; $i -lt $pageSize; $i++) {
            $this.Console.SetCursorPosition(0, $startTop + $i)
            $this.Console.ClearCurrentLine()
            
            $itemIndex = $viewportStart + $i
            if ($itemIndex -lt $items.Count) {
                $item = $items[$itemIndex]
                $isSelected = ($itemIndex -eq $selectedIndex)
                $prefix = if ($isSelected) { ">" } else { " " }
                $color = if ($isSelected) { [Constants]::ColorSelected } else { [Constants]::ColorMenuText }
                
                if ($item.Id -eq "BACK_BUTTON") {
                    $this.Console.WriteColored("  $prefix $( $item.Name )", $color)
                }
                else {
                    $this.Console.WriteColored("  $prefix $( $item.Name): ", $color)
                    
                    if ($item.Id -eq "selectedBackground") {
                        $this.RenderBackgroundValue($item, $color, $GetLoc)
                    }
                    else {
                        $this.Console.WriteColored($item.CurrentValue, $color)
                    }
                }
            }
        }
    }
    
    # Special rendering for background color preview
    hidden [void] RenderBackgroundValue([hashtable]$item, [ConsoleColor]$defaultColor, [scriptblock]$GetLoc) {
        $bgVal = $item.CurrentValue
        $bgDisplay = if ($bgVal -eq 'None') { 
            & $GetLoc "Color.None" "No background" 
        } else { 
            & $GetLoc "Color.$bgVal" $bgVal 
        }
        
        $fgColor = if ($bgVal -ne 'None' -and ($bgVal -as [System.ConsoleColor])) { 
            $bgVal 
        } else { 
            $defaultColor 
        }
        $this.Console.WriteColored($bgDisplay, $fgColor)
    }
    
    # Render footer with message or help text
    [void] RenderFooter([string]$message, [int]$timeout, [int]$footerStart, [scriptblock]$GetLoc) {
        $this.Console.SetCursorPosition(0, $footerStart)
        $this.Console.ClearCurrentLine()
        
        # Separator Line
        $sep = "=" * [Constants]::UIWidth
        $this.Console.WriteColored($sep, [Constants]::ColorSeparator)
        
        # Message / Help
        $this.Console.SetCursorPosition(0, $footerStart + 1)
        $this.Console.ClearCurrentLine()
        
        if ($message -ne "" -and $timeout -gt 0) {
            $this.Console.WriteColored("  $message", [ConsoleColor]::Green)
        } else {
            $hint = & $GetLoc "Pref.Hint" "Use Arrows to navigate | Enter to change/select | Q/Left to go back"
            $this.Console.WriteColored("  $hint", [Constants]::ColorHint)
        }
    }
    
    # Render header (if enabled)
    [int] RenderHeader([string]$title) {
        if ($this.Renderer.ShouldShowHeaders()) {
            $this.Renderer.RenderHeader($title)
            Write-Host ""
        }
        return $this.Console.GetCursorTop()
    }
}
