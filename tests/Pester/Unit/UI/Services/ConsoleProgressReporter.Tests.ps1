# tests/Pester/Unit/UI/Services/ConsoleProgressReporter.Tests.ps1

Describe "ConsoleProgressReporter" {
    BeforeAll {
        $scriptRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
        . "$scriptRoot/Test-Setup.ps1"
    }

    BeforeEach {
        $mockConsoleHelper = [ConsoleHelper]::new()
        
        $mockProgressIndicator = [PSCustomObject]@{
            RenderProgressBarCalled = $false
            CompleteProgressBarCalled = $false
            LastMessage = $null
            LastCurrent = $null
            LastTotal = $null
        } | Add-Member -MemberType ScriptMethod -Name RenderProgressBar -Value {
            param([string]$message, [int]$current, [int]$total)
            $this.RenderProgressBarCalled = $true
            $this.LastMessage = $message
            $this.LastCurrent = $current
            $this.LastTotal = $total
        } -PassThru | Add-Member -MemberType ScriptMethod -Name CompleteProgressBar -Value {
            $this.CompleteProgressBarCalled = $true
        } -PassThru
    }

    Context "Constructor" {
        It "Initializes with ConsoleHelper" {
            $reporter = [ConsoleProgressReporter]::new($mockConsoleHelper)
            $reporter.ConsoleHelper | Should -Not -BeNull
            $reporter.ProgressIndicator | Should -Not -BeNull
        }
    }

    Context "Report" {
        It "Calls ProgressIndicator.RenderProgressBar with correct parameters" {
            $reporter = [ConsoleProgressReporter]::new($mockConsoleHelper)
            $reporter.ProgressIndicator = $mockProgressIndicator
            
            $reporter.Report("Loading repos", 5, 10)
            
            $mockProgressIndicator.RenderProgressBarCalled | Should -BeTrue
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
            
            $mockProgressIndicator.CompleteProgressBarCalled | Should -BeTrue
        }
    }
}
