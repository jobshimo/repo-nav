
class QuickChangeFlowController {
    [CommandContext] $Context
    [object] $Repo
    [GitService] $GitService
    
    QuickChangeFlowController([CommandContext]$context, [object]$repo) {
        $this.Context = $context
        $this.Repo = $repo
        $this.GitService = $context.RepoManager.GitService
    }
    
    [string] Start() {
        while ($true) {
            # 1. Check Status
            $hasChanges = $this.GitService.HasUncommittedChanges($this.Repo.FullPath)
            
            # 2. Prepare Menu
            $title = $this.Context.LocalizationService.Get("Flow.Quick.Title", "QUICK CHANGES DASHBOARD")
            
            $statusText = if ($hasChanges) { 
                $this.Context.LocalizationService.Get("Flow.Quick.Status.Dirty", "Status: Uncommitted changes detected")
            } else {
                $this.Context.LocalizationService.Get("Flow.Quick.Status.Clean", "Status: Working directory clean") 
            }
            
            # Options
            $optCommit = $this.Context.LocalizationService.Get("Flow.Quick.Opt.Commit", "Commit Changes")
            $optStash = $this.Context.LocalizationService.Get("Flow.Quick.Opt.Stash", "Stash Changes")
            
            $options = @()
            
            # Only enable Commit/Stash if there are changes? 
            # Stash can be done even if clean? No, usually nothing to stash.
            # Commit needs changes.
            
            if ($hasChanges) {
                $options += @{ DisplayText = $optCommit; Value = "Commit" }
                $options += @{ DisplayText = $optStash; Value = "Stash" }
            } else {
                 # If no changes, provide a refresh option so the menu doesn't exit immediately
                 $optRefresh = $this.Context.LocalizationService.Get("Flow.Quick.Opt.Refresh", "Check Status")
                 $options += @{ DisplayText = $optRefresh; Value = "Refresh" }
            }
            
            $cancelText = $this.Context.LocalizationService.Get("Flow.Quick.Back", "Back to Menu")
            
            # Show Menu
            $selection = $this.Context.OptionSelector.ShowSelection($title, $options, $null, $cancelText, $false, $statusText, $true)
            
            if ($null -eq $selection) {
                return $this.Context.LocalizationService.Get("Msg.ActionCancelled", "Operation cancelled.")
            }
            
            # 3. Handle Action
            switch ($selection) {
                "Commit"  { $this.HandleCommit() }
                "Stash"   { $this.HandleStash() }
                "Refresh" { Start-Sleep -Milliseconds 100 } # Just loop
            }
            
            # Loop continues to show updated status
        }
        return "" # Unreachable but required by parser
    }
    
    hidden [void] HandleCommit() {
        $this.Context.Console.NewLine()
        $prompt = $this.Context.LocalizationService.Get("Flow.Quick.Prompt.CommitMsg", "Enter commit message: ")
        $this.Context.Console.WriteColored("  $prompt", [Constants]::ColorMenuText)
        $this.Context.Console.ShowCursor()
        $message = Read-Host
        $this.Context.Console.HideCursor()
        
        if ([string]::IsNullOrWhiteSpace($message)) {
             $this.ShowMessage($this.Context.LocalizationService.Get("Error.Aborted", "Aborted (Empty message)"), [Constants]::ColorWarning)
             return
        }
        
        $this.ShowMessage($this.Context.LocalizationService.Get("Flow.Quick.Op.Committing", "Committing..."), [Constants]::ColorHint)
        
        # Add All
        $addRes = $this.GitService.Add($this.Repo.FullPath, ".")
        if (-not $addRes.Success) {
            $this.ShowMessage("Failed to stage files: $($addRes.Output)", [Constants]::ColorError)
            Start-Sleep -Seconds 2
            return
        }
        
        # Commit
        $res = $this.GitService.Commit($this.Repo.FullPath, $message)
        if ($res.Success) {
            $this.ShowMessage($this.Context.LocalizationService.Get("Status.Success", "Success!"), [Constants]::ColorSuccess)
        } else {
            $this.ShowMessage("Commit failed: $($res.Output)", [Constants]::ColorError)
        }
        Start-Sleep -Milliseconds 1000
    }
    
    hidden [void] HandleStash() {
        $this.Context.Console.NewLine()
        $prompt = $this.Context.LocalizationService.Get("Flow.Quick.Prompt.StashName", "Enter stash name (optional): ")
        $this.Context.Console.WriteColored("  $prompt", [Constants]::ColorMenuText)
        $this.Context.Console.ShowCursor()
        $name = Read-Host
        $this.Context.Console.HideCursor()
        
        $this.ShowMessage($this.Context.LocalizationService.Get("Flow.Quick.Op.Stashing", "Stashing changes..."), [Constants]::ColorHint)
        
        $res = $this.GitService.Stash($this.Repo.FullPath, $name)
        if ($res.Success) {
            $this.ShowMessage($this.Context.LocalizationService.Get("Status.Success", "Success!"), [Constants]::ColorSuccess)
        } else {
            $this.ShowMessage("Stash failed: $($res.Output)", [Constants]::ColorError)
        }
        Start-Sleep -Milliseconds 1000
    }
    
    hidden [void] ShowMessage([string]$text, [ConsoleColor]$color) {
        $this.Context.Console.WriteLineColored("  $text", $color)
    }
}
