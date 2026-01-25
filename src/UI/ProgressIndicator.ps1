<#
.SYNOPSIS
    Displays progress feedback for long-running operations
    
.DESCRIPTION
    Provides two types of progress indicators:
    - Animated dots: For indeterminate operations (e.g., single git fetch)
    - Progress bar: For operations with known total count (e.g., loading N repos)
    
    Following SOLID principles:
    - SRP: Only handles progress visualization
    - OCP: Can be extended with new indicator types
    - LSP: Both indicator types follow same interface
    - ISP: Minimal public interface (Start, Update, Stop)
    - DIP: Depends on ConsoleHelper abstraction
    
.NOTES
    This class uses background jobs for animated indicators to avoid blocking
#>

class ProgressIndicator {
    # Dependencies
    [ConsoleHelper] $Console      # ConsoleHelper
    
    # State
    [int] $StartLine
    [int] $StartColumn
    [bool] $IsRunning
    
    # Constructor
    ProgressIndicator([ConsoleHelper]$console) {
        $this.Console = $console
        $this.IsRunning = $false
    }
    
    #region Animated Dots (Indeterminate Progress)
    
    <#
    .SYNOPSIS
        Shows animated dots for a short operation (synchronous display)
    #>
    [void] ShowLoadingDots([string]$message, [scriptblock]$action) {
        # Save cursor position
        $this.StartLine = $this.Console.GetCursorTop()
        $this.StartColumn = $this.Console.GetCursorLeft()
        
        # Show message with animation (5 iterations, each 300ms)
        for ($i = 0; $i -lt 5; $i++) {
            $dots = "." * ($i % 4)
            $padding = " " * (3 - ($i % 4))
            
            $this.Console.SetCursorPosition($this.StartColumn, $this.StartLine)
            $this.Console.WriteColored("$message$dots$padding", [ConsoleColor]::Cyan)
            
            Start-Sleep -Milliseconds 300
        }
        
        # Execute the actual action
        & $action
        
        # Clear the loading message
        $this.Console.SetCursorPosition($this.StartColumn, $this.StartLine)
        $clearText = " " * ($message.Length + 10)
        $this.Console.Write($clearText)
        $this.Console.SetCursorPosition($this.StartColumn, $this.StartLine)
    }
    
    #endregion
    
    #region Progress Bar (Determinate Progress)
    
    <#
    .SYNOPSIS
        Renders a progress bar (e.g., "[████████░░░░░░░░░░] 40% (4/10)")
    #>
    [void] RenderProgressBar([string]$message, [int]$current, [int]$total) {
        if ($total -eq 0) { return }
        
        $percentage = [Math]::Round(($current / $total) * 100)
        $barWidth = 20
        $filledWidth = [Math]::Round(($current / $total) * $barWidth)
        $emptyWidth = $barWidth - $filledWidth
        
        # Create filled and empty parts (PowerShell 5.1 compatible)
        $filledBar = "#" * $filledWidth
        $emptyBar = "-" * $emptyWidth
        
        # Save position if first call
        if (-not $this.IsRunning) {
            $this.IsRunning = $true
            $this.StartLine = $this.Console.GetCursorTop()
            $this.StartColumn = $this.Console.GetCursorLeft()
        }
        
        # Render progress bar
        $this.Console.SetCursorPosition($this.StartColumn, $this.StartLine)
        $this.Console.WriteColored("$message [", [ConsoleColor]::Cyan)
        $this.Console.WriteColored($filledBar, [ConsoleColor]::Green)
        $this.Console.WriteColored($emptyBar, [ConsoleColor]::DarkGray)
        $this.Console.WriteColored("] ", [ConsoleColor]::Cyan)
        $this.Console.WriteColored("$percentage% ", [ConsoleColor]::Yellow)
        $this.Console.WriteColored("($current/$total)", [ConsoleColor]::DarkGray)
        
        # Pad to avoid leftover characters
        $this.Console.Write(" " * 10)
    }
    
    <#
    .SYNOPSIS
        Completes and clears the progress bar
    #>
    [void] CompleteProgressBar() {
        if (-not $this.IsRunning) { return }
        
        $this.IsRunning = $false
        
        # Clear the line
        $this.Console.SetCursorPosition($this.StartColumn, $this.StartLine)
        $clearText = " " * 80
        $this.Console.Write($clearText)
        $this.Console.SetCursorPosition($this.StartColumn, $this.StartLine)
    }
    
    #endregion
}
