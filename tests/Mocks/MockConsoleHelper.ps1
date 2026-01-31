<#
.SYNOPSIS
    Mock implementation of ConsoleHelper for testing
    
.DESCRIPTION
    Records all console operations instead of actually writing to the console.
    Useful for testing UI components without requiring a real terminal.
    
.EXAMPLE
    $mock = [MockConsoleHelper]::new()
    $renderer = [UIRenderer]::new($mock, $prefsService)
    $renderer.RenderHeader("Test")
    $mock.WrittenLines.Count # Check how many lines were written
#>

class MockConsoleHelper {
    [System.Collections.ArrayList] $WrittenLines
    [System.Collections.ArrayList] $WrittenTexts
    [System.Collections.ArrayList] $KeyPresses
    [bool] $CursorVisible
    [int] $CursorLeft
    [int] $CursorTop
    
    MockConsoleHelper() {
        $this.WrittenLines = [System.Collections.ArrayList]::new()
        $this.WrittenTexts = [System.Collections.ArrayList]::new()
        $this.KeyPresses = [System.Collections.ArrayList]::new()
        $this.CursorVisible = $true
        $this.CursorLeft = 0
        $this.CursorTop = 0
    }
    
    [void] WriteLineColored([string]$text, [ConsoleColor]$color) {
        $this.WrittenLines.Add(@{
            Text = $text
            Color = $color
            Type = "Line"
        }) | Out-Null
    }
    
    [void] WriteColored([string]$text, [ConsoleColor]$color) {
        $this.WrittenTexts.Add(@{
            Text = $text
            Color = $color
            Type = "Text"
        }) | Out-Null
    }
    
    [void] WriteSeparator([string]$char, [int]$length, [ConsoleColor]$color) {
        $this.WrittenLines.Add(@{
            Text = $char * $length
            Color = $color
            Type = "Separator"
        }) | Out-Null
    }
    
    [void] NewLine() {
        $this.WrittenLines.Add(@{
            Text = ""
            Color = [ConsoleColor]::White
            Type = "NewLine"
        }) | Out-Null
    }
    
    [void] ClearScreen() {
        $this.WrittenLines.Clear()
        $this.WrittenTexts.Clear()
    }
    
    [void] SetCursorPosition([int]$left, [int]$top) {
        $this.CursorLeft = $left
        $this.CursorTop = $top
    }
    
    [void] HideCursor() {
        $this.CursorVisible = $false
    }
    
    [void] ShowCursor() {
        $this.CursorVisible = $true
    }
    
    [object] ReadKey() {
        if ($this.KeyPresses.Count -gt 0) {
            $key = $this.KeyPresses[0]
            $this.KeyPresses.RemoveAt(0)
            return $key
        }
        # Return default Enter key if no keys queued
        return @{
            VirtualKeyCode = 13
            Character = "`r"
        }
    }
    
    # Test helper: Simulate key press
    [void] SimulateKeyPress([int]$virtualKeyCode, [char]$character) {
        $this.KeyPresses.Add(@{
            VirtualKeyCode = $virtualKeyCode
            Character = $character
        }) | Out-Null
    }
    
    # Test helper: Get all written text as single string
    [string] GetAllWrittenText() {
        $allText = ""
        foreach ($item in $this.WrittenLines) {
            $allText += $item.Text + "`n"
        }
        foreach ($item in $this.WrittenTexts) {
            $allText += $item.Text
        }
        return $allText
    }
    
    # Test helper: Check if text was written
    [bool] ContainsText([string]$text) {
        $allText = $this.GetAllWrittenText()
        return $allText -like "*$text*"
    }
    
    # Test helper: Reset for next test
    [void] Reset() {
        $this.WrittenLines.Clear()
        $this.WrittenTexts.Clear()
        $this.KeyPresses.Clear()
        $this.CursorVisible = $true
        $this.CursorLeft = 0
        $this.CursorTop = 0
    }
}
