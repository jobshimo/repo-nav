BeforeAll {
    . "$PSScriptRoot/../../../Test-Setup.ps1"
}

Describe "Proof of Value: Testing Interactive Logic without Interaction" {

    BeforeAll {
        # 1. Define the MOCK CONSOLE (Impossible before refactoring)
        # This class captures output and provides pre-canned input.
        $mockConsoleCode = @'
        class MockConsole : IConsoleHelper {
            [string] $LastWrite
            [System.Collections.ArrayList] $InputQueue
            [bool] $ConfirmResult

            MockConsole() {
                $this.InputQueue = [System.Collections.ArrayList]::new()
                $this.ConfirmResult = $true
            }

            # --- MOCKED METHODS ---
            
            [bool] ConfirmAction([string]$prompt, [bool]$defaultYes) { 
                $this.LastWrite = "PROMPT: $prompt"
                return $this.ConfirmResult 
            }

            [void] Write([string]$text) { $this.LastWrite = $text }
            [void] WriteColored([string]$text, [System.ConsoleColor]$color) { $this.LastWrite = $text }
            [void] WriteLineColored([string]$text, [System.ConsoleColor]$color) { $this.LastWrite = $text }
            
            # --- STUBS (Required by interface) ---
            [void] HideCursor() {}
            [void] ShowCursor() {}
            [void] SetCursorPosition([int]$x, [int]$y) {}
            [int] GetCursorLeft() { return 0 }
            [int] GetCursorTop() { return 0 }
            [void] ClearScreen() {}
            [void] ClearForWorkflow() {}
            [void] ClearCurrentLine() {}
            [void] ClearLine() {}
            [int] GetWindowHeight() { return 25 }
            [int] GetWindowWidth() { return 80 }
            [System.Management.Automation.Host.KeyInfo] ReadKey() { return $null }
            [void] WriteWithBackground([string]$t, [System.ConsoleColor]$f, [System.ConsoleColor]$b) {}
            [void] WriteSeparator([string]$c, [int]$l, [System.ConsoleColor]$col) {}
            [void] NewLine() {}
            [void] WritePadded([string]$t, [System.ConsoleColor]$f, [System.ConsoleColor]$b) {}
            [void] ClearRestOfLine() {}
        }
'@
        # Only Compile if not already exists (Pester re-run safety)
        if (-not ("MockConsole" -as [type])) {
            Invoke-Expression $mockConsoleCode
        }
    }

    Context "When NpmView asks for confirmation (using IConsoleHelper)" {
        
        It "Simulates User saying YES without touching the keyboard" {
            # Arrange
            $mockConsole = [MockConsole]::new()
            $mockConsole.ConfirmResult = $true  # <--- Simulating 'Y'
            
            # Create a Context with our Mock Console
            # We purposely leave OptionSelector null to force it to use Console.ConfirmAction
            $context = [CommandContext]::new()
            $context.Console = $mockConsole
            $context.LocalizationService = $null # Use defaults
            
            $view = [NpmView]::new($context)
            
            # Act
            $result = $view.ConfirmRemoval("MyProject")
            
            # Assert
            $result | Should -Be $true
            $mockConsole.LastWrite | Should -Match "PROMPT: Continue\?"
        }

        It "Simulates User saying NO without touching the keyboard" {
            # Arrange
            $mockConsole = [MockConsole]::new()
            $mockConsole.ConfirmResult = $false  # <--- Simulating 'N'
            
            $context = [CommandContext]::new()
            $context.Console = $mockConsole
            
            $view = [NpmView]::new($context)
            
            # Act
            $result = $view.ConfirmRemoval("MyProject")
            
            # Assert
            $result | Should -Be $false
        }
    }
}
