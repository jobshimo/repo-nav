# tests/Pester/Unit/UI/Services/ConsoleProgressReporter.Tests.ps1

Describe "ConsoleProgressReporter" {
    BeforeAll {
        $projectRoot = (Resolve-Path "$PSScriptRoot/../../../../..").Path
        . "$projectRoot/tests/Test-Setup.ps1" | Out-Null
        
        # Load standard mocks
        . "$projectRoot/tests/Mocks/MockCommonServices.ps1"
    }

    BeforeEach {
        $mockConsoleHelper = [MockConsoleHelper]::new()
        $mockProgressIndicator = [MockProgressIndicator]::new()
    }

    Context "Constructor" {
        It "Initializes with ConsoleHelper" {
            $reporter = [ConsoleProgressReporter]::new($mockConsoleHelper)
            $reporter.ConsoleHelper | Should -Not -BeNull
            ($reporter.ConsoleHelper -is [IConsoleHelper]) | Should -BeTrue
        }
    }

    Context "Report" {
        It "Calls ProgressIndicator.RenderProgressBar with correct parameters" {
            $reporter = [ConsoleProgressReporter]::new($mockConsoleHelper)
            $reporter.ProgressIndicator = $mockProgressIndicator
            
            $reporter.Report("Loading repos", 5, 10)
            
            $mockProgressIndicator.RenderCalled | Should -BeTrue
            $mockProgressIndicator.LastMessage | Should -Be "Loading repos"
            $mockProgressIndicator.LastCurrent | Should -Be 5
            $mockProgressIndicator.LastTotal | Should -Be 10
        }

        It "Handles zero total" {
            $reporter = [ConsoleProgressReporter]::new($mockConsoleHelper)
            $reporter.ProgressIndicator = $mockProgressIndicator
            
            $reporter.Report("Processing", 0, 0)
            
            $mockProgressIndicator.LastCurrent | Should -Be 0
            $mockProgressIndicator.LastTotal | Should -Be 0
        }
    }

    Context "Complete" {
        It "Calls ProgressIndicator.CompleteProgressBar" {
            $reporter = [ConsoleProgressReporter]::new($mockConsoleHelper)
            $reporter.ProgressIndicator = $mockProgressIndicator
            
            $reporter.Complete()
            
            $mockProgressIndicator.CompleteCalled | Should -BeTrue
        }
    }
}
