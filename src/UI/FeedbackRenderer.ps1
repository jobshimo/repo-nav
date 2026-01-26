<#
.SYNOPSIS
    FeedbackRenderer - Handles rendering of system feedback messages
    
.DESCRIPTION
    Extracted from UIRenderer to follow SRP.
    Responsible for rendering errors, success messages, and warnings.
#>

class FeedbackRenderer {
    [ConsoleHelper] $Console
    [LocalizationService] $LocalizationService

    # Constructor
    FeedbackRenderer([ConsoleHelper]$console, [LocalizationService]$localizationService) {
        $this.Console = $console
        $this.LocalizationService = $localizationService
    }

    # Helper for localization
    hidden [string] GetLoc([string]$key, [string]$default) {
        if ($null -ne $this.LocalizationService) {
            return $this.LocalizationService.Get($key)
        }
        return $default
    }

    # Render error message
    [void] RenderError([string]$message) {
        # Simplistic format since we can't easily pass args to PS format for partial string
        # If message is already localized/dynamic, we just prepend Error if needed.
        # But here we just print as is usually.
        $this.Console.WriteLineColored("Error: $message", [Constants]::ColorError)
    }
    
    # Render success message
    [void] RenderSuccess([string]$message) {
        $this.Console.WriteLineColored($message, [Constants]::ColorSuccess)
    }
    
    # Render warning message
    [void] RenderWarning([string]$message) {
        $this.Console.WriteLineColored($message, [Constants]::ColorWarning)
    }
}
