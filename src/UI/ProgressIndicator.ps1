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
    [object] $Console      # ConsoleHelper
    
    # State
    [string] $Message
    [int] $StartLine
    [int] $StartColumn
    [object] $AnimationJob
    [bool] $IsRunning
    
    # Constructor
    ProgressIndicator([object]$console) {
        $this.Console = $console
        $this.IsRunning = $false
    }
    
    #region Animated Dots (Indeterminate Progress)
    
    <#
    .SYNOPSIS
        Starts an animated dots indicator (e.g., "Loading... .", "Loading... ..", "Loading... ...")
    #>
    [void] StartAnimatedDots([string]$message) {
        $this.StopIfRunning()
        
        $this.Message = $message
        $this.IsRunning = $true
        
        # Save cursor position
        $this.StartLine = [Console]::CursorTop
        $this.StartColumn = [Console]::CursorLeft
        
        # Start background animation
        $this.AnimationJob = Start-Job -ScriptBlock {
            param($message, $line, $col)
            
            $dotCount = 0
            while ($true) {
                $dots = "." * $dotCount
                $padding = " " * (3 - $dotCount)  # Pad to avoid leftover characters
                
                [Console]::SetCursorPosition($col, $line)
                Write-Host "$message $dots$padding" -NoNewline -ForegroundColor Cyan
                
                $dotCount = ($dotCount + 1) % 4
                Start-Sleep -Milliseconds 400
            }
        } -ArgumentList $this.Message, $this.StartLine, $this.StartColumn
    }
    
    <#
    .SYNOPSIS
        Stops the animated dots indicator
    #>
    [void] StopAnimatedDots() {
        $this.StopIfRunning()
        
        # Clear the line
        [Console]::SetCursorPosition($this.StartColumn, $this.StartLine)
        $clearText = " " * ($this.Message.Length + 10)
        Write-Host $clearText -NoNewline
        [Console]::SetCursorPosition($this.StartColumn, $this.StartLine)
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
            $this.StartLine = [Console]::CursorTop
            $this.StartColumn = [Console]::CursorLeft
        }
        
        # Render progress bar
        [Console]::SetCursorPosition($this.StartColumn, $this.StartLine)
        Write-Host "$message [" -NoNewline -ForegroundColor Cyan
        Write-Host $filledBar -NoNewline -ForegroundColor Green
        Write-Host $emptyBar -NoNewline -ForegroundColor DarkGray
        Write-Host "] " -NoNewline -ForegroundColor Cyan
        Write-Host "$percentage% " -NoNewline -ForegroundColor Yellow
        Write-Host "($current/$total)" -NoNewline -ForegroundColor DarkGray
        
        # Pad to avoid leftover characters
        Write-Host (" " * 10) -NoNewline
    }
    
    <#
    .SYNOPSIS
        Completes and clears the progress bar
    #>
    [void] CompleteProgressBar() {
        if (-not $this.IsRunning) { return }
        
        $this.IsRunning = $false
        
        # Clear the line
        [Console]::SetCursorPosition($this.StartColumn, $this.StartLine)
        $clearText = " " * 80
        Write-Host $clearText -NoNewline
        [Console]::SetCursorPosition($this.StartColumn, $this.StartLine)
    }
    
    #endregion
    
    #region Helper Methods
    
    <#
    .SYNOPSIS
        Stops any running animation/progress
    #>
    [void] StopIfRunning() {
        if ($this.IsRunning -and $null -ne $this.AnimationJob) {
            Stop-Job -Job $this.AnimationJob -ErrorAction SilentlyContinue
            Remove-Job -Job $this.AnimationJob -Force -ErrorAction SilentlyContinue
            $this.AnimationJob = $null
        }
        $this.IsRunning = $false
    }
    
    #endregion
}
