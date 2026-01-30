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
            [Console]::CursorVisible = $false
        }
        catch {
            # Fallback for environments where Console API fails
        }
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
            [Console]::CursorVisible = $true
        }
        catch {
            # Fallback
        }
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
    
    # Get current cursor X (Left) position
    [int] GetCursorLeft() {
        return $global:Host.UI.RawUI.CursorPosition.X
    }

    # Get current cursor Y (Top) position
    [int] GetCursorTop() {
        return $global:Host.UI.RawUI.CursorPosition.Y
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
        # Ensure cursor is visible for input
        $this.ShowCursor()
        
        $suffix = if ($defaultYes) { "(Y/n)" } else { "(y/N)" }
        Write-Host "$prompt $suffix : " -NoNewline -ForegroundColor ([Constants]::ColorLabel)
        $response = Read-Host
        
        # Hide cursor again after input
        $this.HideCursor()
        
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
        $currentLength = $rawUI.WindowSize.Width
        # Safety: Writing to the last column can cause wrap. Reduce by 1.
        if ($currentLength -gt 1) { $currentLength = $currentLength - 1 }
        
        $this.SetCursorPosition(0, $rawUI.CursorPosition.Y)
        Write-Host (" " * $currentLength) -NoNewline
        $this.SetCursorPosition(0, $rawUI.CursorPosition.Y)
    }

    # Alias for ClearCurrentLine (Common name)
    [void] ClearLine() {
        $this.ClearCurrentLine()
    }
    # Get window height
    [int] GetWindowHeight() {
        try {
            return $global:Host.UI.RawUI.WindowSize.Height
        }
        catch {
            return 25 # Fallback default
        }
    }
    
    # Get window width
    [int] GetWindowWidth() {
        return $global:Host.UI.RawUI.WindowSize.Width
    }
    
    # Read key press (non-blocking)
    [System.Management.Automation.Host.KeyInfo] ReadKey() {
        return $global:Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }

    # Wrapper for Write-Host with NoNewline
    [void] Write([string]$text) {
        Write-Host $text -NoNewline
    }

    # Wrapper for Write-Host with NoNewline and ForegroundColor
    [void] WriteColored([string]$text, [System.ConsoleColor]$color) {
        Write-Host $text -NoNewline -ForegroundColor $color
    }

    # Wrapper for Write-Host with ForegroundColor (with newline)
    [void] WriteLineColored([string]$text, [System.ConsoleColor]$color) {
        Write-Host $text -ForegroundColor $color
    }
    
    # Wrapper for Write-Host with Background and Foreground Color (NoNewline)
    [void] WriteWithBackground([string]$text, [System.ConsoleColor]$foreground, [System.ConsoleColor]$background) {
        Write-Host $text -NoNewline -ForegroundColor $foreground -BackgroundColor $background
    }

    # Write a separator line
    [void] WriteSeparator([string]$char, [int]$length, [System.ConsoleColor]$color) {
        Write-Host ($char * $length) -ForegroundColor $color
    }

    # Write a new line
    [void] NewLine() {
        Write-Host ""
    }

    # Write text padded to window width (avoids clearing line first)
    [void] WritePadded([string]$text, [System.ConsoleColor]$foregroundColor, [System.ConsoleColor]$backgroundColor = [ConsoleColor]::Black) {
        $width = $this.GetWindowWidth()
        $targetLength = $width - 1
        
        # Truncate if too long (safety)
        if ($text.Length -ge $targetLength) {
            $text = $text.Substring(0, $targetLength)
        }
        
        $padded = $text.PadRight($targetLength)
        
        if ($backgroundColor -ne [ConsoleColor]::Black) {
            Write-Host $padded -NoNewline -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor
        } else {
            # If no background specified, explicit black background ensures we "erase" underlying content
            Write-Host $padded -NoNewline -ForegroundColor $foregroundColor -BackgroundColor Black
        }
    }

    # Clear the rest of the current line (from cursor to end)
    [void] ClearRestOfLine() {
        $rawUI = $global:Host.UI.RawUI
        $currentX = $rawUI.CursorPosition.X
        $width = $rawUI.WindowSize.Width
        
        # Max index is width - 1
        $remaining = $width - $currentX - 1
        
        if ($remaining -gt 0) {
            Write-Host (" " * $remaining) -NoNewline
        }
    }
}
