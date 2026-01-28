<#
.SYNOPSIS
    Console implementation of IProgressReporter
    
.DESCRIPTION
    Uses ProgressIndicator to render progress in the console.
#>

class ConsoleProgressReporter : IProgressReporter {
    [ProgressIndicator] $ProgressIndicator
    [object] $ConsoleHelper
    
    ConsoleProgressReporter([object]$consoleHelper) {
        $this.ConsoleHelper = $consoleHelper
        $this.ProgressIndicator = [ProgressIndicator]::new($consoleHelper)
    }
    
    [void] Report([string]$message, [int]$current, [int]$total) {
        $this.ProgressIndicator.RenderProgressBar($message, $current, $total)
    }
    
    [void] Complete() {
        $this.ProgressIndicator.CompleteProgressBar()
    }
}
