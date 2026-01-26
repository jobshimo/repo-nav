<#
.SYNOPSIS
    ColorRenderer - Handles rendering of color selection items
    
.DESCRIPTION
    Extracted from UIRenderer to follow SRP.
    Responsible for rendering the color selection list items.
#>

class ColorRenderer {
    [ConsoleHelper] $Console
    [UserPreferencesService] $PreferencesService
    [LocalizationService] $LocalizationService

    # Constructor
    ColorRenderer([ConsoleHelper]$console, [UserPreferencesService]$preferencesService, [LocalizationService]$localizationService) {
        $this.Console = $console
        $this.PreferencesService = $preferencesService
        $this.LocalizationService = $localizationService
    }

    # Helper for localization
    hidden [string] GetLoc([string]$key, [string]$default) {
        if ($null -ne $this.LocalizationService) {
            return $this.LocalizationService.Get($key)
        }
        return $default
    }

    # Render color selection item
    [void] RenderColorItem([string]$color, [bool]$isSelected) {
        $backgroundColor = $null
        if ($isSelected) {
            $preferences = $this.PreferencesService.LoadPreferences()
            $bgColor = $preferences.display.selectedBackground
            if ($bgColor -ne 'None') {
                $backgroundColor = $bgColor
            }
        }
        
        $displayColor = $this.GetLoc("Color.$color", $color)

        if ($isSelected) {
            $this.Console.WriteColored("  > ", [Constants]::ColorSelected)
            if ($backgroundColor) {
                $this.Console.WriteWithBackground($displayColor, $color, $backgroundColor)
            } else {
                $this.Console.WriteColored($displayColor, $color)
            }
            $this.Console.NewLine()
        } else {
            $this.Console.Write("    ")
            $this.Console.WriteLineColored($displayColor, $color)
        }
    }
    
    # Update color item at specific line
    [void] UpdateColorItemAt([int]$lineNumber, [string]$color, [bool]$isSelected) {
        $this.Console.SetCursorPosition(0, $lineNumber)
        $this.Console.ClearCurrentLine()
        $this.RenderColorItem($color, $isSelected)
    }
}
