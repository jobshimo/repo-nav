<#
.SYNOPSIS
    ConsoleHelper - Low-level console manipulation utilities
    
.DESCRIPTION
    Following SOLID principles:
    - SRP: Only responsible for console/cursor manipulation
    - ISP: Small, focused interface for console operations
    
    This class provides utilities for:
    - Cursor positioning and visibility
    - Screen clearing
    - Line clearing
    - Console measurements
#>

class ConsoleHelper {
    
    # Hide cursor
    [void] HideCursor() {
        try {
            $global:Host.UI.RawUI.CursorSize = 0
        }
        catch {
            # Silently fail if not supported
        }
    }
    
    # Show cursor
    [void] ShowCursor() {
        try {
            $global:Host.UI.RawUI.CursorSize = 25
        }
        catch {
            # Silently fail if not supported
        }
    }
    
    # Move cursor to specific position
    [void] SetCursorPosition([int]$x, [int]$y) {
        try {
            $global:Host.UI.RawUI.CursorPosition = @{ X = $x; Y = $y }
        }
        catch {
            # Silently fail if position is invalid
        }
    }
    
    # Clear entire screen
    [void] ClearScreen() {
        Clear-Host
    }
    
    # Clear screen and prepare for interactive workflow
    [void] ClearForWorkflow() {
        Clear-Host
    }
    
    # Prompt user for confirmation with configurable default
    [bool] ConfirmAction([string]$prompt, [bool]$defaultYes = $true) {
        $suffix = if ($defaultYes) { "(Y/n)" } else { "(y/N)" }
        Write-Host "$prompt $suffix : " -NoNewline -ForegroundColor ([Constants]::ColorLabel)
        $response = Read-Host
        
        # Empty response uses the default
        if ([string]::IsNullOrWhiteSpace($response)) {
            return $defaultYes
        }
        
        # Explicit yes
        return ($response -eq 'y' -or $response -eq 'Y')
    }
    
    # Clear current line
    [void] ClearCurrentLine() {
        $rawUI = $global:Host.UI.RawUI
        $this.SetCursorPosition(0, $rawUI.CursorPosition.Y)
        Write-Host (" " * $rawUI.WindowSize.Width) -NoNewline
        $this.SetCursorPosition(0, $rawUI.CursorPosition.Y)
    }
    
    # Get window width
    [int] GetWindowWidth() {
        return $global:Host.UI.RawUI.WindowSize.Width
    }
    
    # Read key press (non-blocking)
    [System.Management.Automation.Host.KeyInfo] ReadKey() {
        return $global:Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}
