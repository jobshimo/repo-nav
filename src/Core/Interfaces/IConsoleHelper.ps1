class IConsoleHelper {
    [void] HideCursor() {}
    [void] ShowCursor() {}
    [void] SetCursorPosition([int]$x, [int]$y) {}
    [int] GetCursorLeft() { return 0 }
    [int] GetCursorTop() { return 0 }
    [void] ClearScreen() {}
    [void] ClearForWorkflow() {}
    [bool] ConfirmAction([string]$prompt, [bool]$defaultYes) { return $false }
    [void] ClearCurrentLine() {}
    [void] ClearLine() {}
    [int] GetWindowHeight() { return 0 }
    [int] GetWindowWidth() { return 0 }
    [System.Management.Automation.Host.KeyInfo] ReadKey() { return $null }
    [void] Write([string]$text) {}
    [void] WriteColored([string]$text, [System.ConsoleColor]$color) {}
    [void] WriteLineColored([string]$text, [System.ConsoleColor]$color) {}
    [void] WriteWithBackground([string]$text, [System.ConsoleColor]$foreground, [System.ConsoleColor]$background) {}
    [void] WriteSeparator([string]$char, [int]$length, [System.ConsoleColor]$color) {}
    [void] NewLine() {}
    [void] WritePadded([string]$text, [System.ConsoleColor]$foregroundColor, [System.ConsoleColor]$backgroundColor) {}
    [void] ClearRestOfLine() {}
}
