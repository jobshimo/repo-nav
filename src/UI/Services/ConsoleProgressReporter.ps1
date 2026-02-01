<#
.SYNOPSIS
    Console implementation of IProgressReporter
    
.DESCRIPTION
    Uses ProgressIndicator to render progress in the console.
#>

class ConsoleProgressReporter : IProgressReporter {
    [IProgressIndicator] $ProgressIndicator
    [IConsoleHelper] $ConsoleHelper
    
    ConsoleProgressReporter([IConsoleHelper]$consoleHelper) {
        $this.ConsoleHelper = $consoleHelper
        # Default initialization, but allow override via property for testing
        $this.ProgressIndicator = [ProgressIndicator]::new($consoleHelper)
    }
    
    [void] Report([string]$message, [int]$current, [int]$total) {
        $this.ProgressIndicator.RenderProgressBar($message, $current, $total)
    }
    
    [void] Complete() {
        $this.ProgressIndicator.CompleteProgressBar()
    }
}
