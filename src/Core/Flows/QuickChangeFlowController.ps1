
class QuickChangeFlowController {
    [CommandContext] $Context
    [object] $Repo
    [GitService] $GitService
    [FilteredListSelector] $ListSelector
    
    QuickChangeFlowController([CommandContext]$context, [object]$repo) {
        $this.Context = $context
        $this.Repo = $repo
        $this.GitService = $context.RepoManager.GitService
        $this.ListSelector = [FilteredListSelector]::new($context.Console, $context.Renderer)
    }
    
    [string] Start() {
        $tempMessage = ""
        $tempMessageColor = [Constants]::ColorWarning
        
        while ($true) {
            # 1. State
            $hasChanges = $this.GitService.HasUncommittedChanges($this.Repo.FullPath)
            $currentBranch = $this.GitService.GetCurrentBranch($this.Repo.FullPath)
            $remoteUrl = $this.GitService.GetRemoteUrl($this.Repo.FullPath)
            $hasRemote = -not [string]::IsNullOrWhiteSpace($remoteUrl)
            
            # 2. Logic for Push
            $needsPush = $false
            if ($hasRemote) {
                $remotes = $this.GitService.GetRemoteBranches($this.Repo.FullPath)
                $target = "origin/$currentBranch"
                $existsOnRemote = $remotes -contains $target
                
                if (-not $existsOnRemote) {
                    $needsPush = $true # New branch
                } elseif ($this.GitService.HasUnpushedCommits($this.Repo.FullPath)) {
                    $needsPush = $true # Ahead
                }
            }
            
            # 3. Prepare Menu
            $title = $this.Context.LocalizationService.Get("Flow.Quick.Title", "QUICK CHANGES DASHBOARD")
            
            # Status line
            $statusText = if ($hasChanges) { 
                $this.Context.LocalizationService.Get("Flow.Quick.Status.Dirty", "Status: Uncommitted changes detected")
            } else {
                $this.Context.LocalizationService.Get("Flow.Quick.Status.Clean", "Status: Working directory clean") 
            }
            
            $options = @()
            
            # OPT 1: Current Branch (Switch)
            $lblCurrent = $this.Context.LocalizationService.Get("Flow.Quick.Current", "Current Branch: {0}") -f $currentBranch
            $options += @{ DisplayText = $lblCurrent; Value = "SwitchBranch" }
            
            # OPT 2: Push (Contextual)
            if ($needsPush) {
                $lblPush = $this.Context.LocalizationService.Get("Flow.Quick.Opt.PushBranch", "Push Local Branch")
                $options += @{ DisplayText = "  $lblPush"; Value = "PushBranch" }
            }
            
            # OPT 3: Dirty Actions
            if ($hasChanges) {
                $optCommit = $this.Context.LocalizationService.Get("Flow.Quick.Opt.Commit", "Commit Changes")
                $optStash = $this.Context.LocalizationService.Get("Flow.Quick.Opt.Stash", "Stash Changes")
                $options += @{ DisplayText = $optCommit; Value = "Commit" }
                $options += @{ DisplayText = $optStash; Value = "Stash" }
            }
            
            # OPT 4: Global Actions
            $optCreate = $this.Context.LocalizationService.Get("Flow.Quick.Opt.CreateBranch", "Create New Branch")
            $options += @{ DisplayText = $optCreate; Value = "CreateBranch" }
            
            # OPT 5: Back
            $optBack = $this.Context.LocalizationService.Get("Flow.Quick.Back", "Back to Menu")
            $options += @{ DisplayText = $optBack; Value = "Back" }
            
            $hintText = $this.Context.LocalizationService.Get("Msg.SelectOption", "Select an option")
            
            # Pass $tempMessage as description if set
            $desc = if ($tempMessage) { $tempMessage } else { $statusText }
            # Use Red for error warnings (tempMessage), otherwise standard color for status
            $descColor = if ($tempMessage) { $tempMessageColor } else { [Constants]::ColorWarning } # Warning is default yellow, maybe use Gray for clean status? 
            # Actually statusText is informational, typically Gray/Green/Yellow depending on state, but here we pass it as Description.
            # If dirty, statusText is "Status: Uncommitted...", which should be Yellow.
            # If clean, "Status: Clean", which could be Gray.
            # But OptionSelector currently takes one color. Let's stick to Warning(Yellow) for status, and Error(Red) for alerts.
            
            # Override for status text color if not an error message
            if (-not $tempMessage) {
                 if ($hasChanges) { $descColor = [Constants]::ColorWarning } else { $descColor = [ConsoleColor]::Gray }
            }
            
            $selection = $this.Context.OptionSelector.ShowSelection($title, $options, $null, $hintText, $false, $desc, $descColor, $true)
            
            # Clear temporary message after showing once (it persists if user cancels/does nothing? No, ShowSelection loops until selection/cancel)
            # If user selects something, loop re-runs. We want to clear the message unless the action sets it again.
            $tempMessage = ""
            
            if ($null -eq $selection -or $selection -eq "Back") {
                return $this.Context.LocalizationService.Get("Msg.ActionCancelled", "Operation cancelled.")
            }
            
            switch ($selection) {
                "SwitchBranch" { 
                    $err = $this.HandleSwitchBranch($hasChanges) 
                    if ($err) {
                        $tempMessage = $err
                        $tempMessageColor = [Constants]::ColorError # Red
                    }
                }
                "PushBranch"   { $this.HandlePushBranch() }
                "Commit"       { $this.HandleCommit() }
                "Stash"        { $this.HandleStash() }
                "CreateBranch" { $this.HandleCreateBranch() }
            }
        }
        return ""
    }
    
    hidden [string] HandleSwitchBranch([bool]$hasChanges) {
        if ($hasChanges) {
            return $this.Context.LocalizationService.Get("Flow.Warning.DirtySwitch", "Running changes! Commit or stash before switching branches.")
        }
        
        $branches = $this.GitService.GetBranches($this.Repo.FullPath)
        $current = $this.GitService.GetCurrentBranch($this.Repo.FullPath)
        
        $title = "QUICK CHANGES > SWITCH BRANCH"
        $sel = $this.ListSelector.ShowSelection($title, $branches, @{ Prompt="Select Branch"; CurrentItem=$current; InitialFocus=[Constants]::FocusInput })
        
        if ($null -ne $sel) {
            $target = $sel.Value.Trim()
            if ($target -ne $current) {
                $this.ShowMessage("Checking out '$target'...", [Constants]::ColorHint)
                $res = $this.GitService.Checkout($this.Repo.FullPath, $target)
                if (-not $res.Success) {
                     # Return error to show in loop? Or show immediately?
                     # Checkout errors are usually blocking/important, so showing immediate is fine. 
                     # But we could return it too if we want.
                     $this.ShowMessage("Error: $($res.Output)", [Constants]::ColorError)
                     Start-Sleep -Seconds 2
                }
            }
        }
        return ""
    }
    
    hidden [void] HandlePushBranch() {
        $current = $this.GitService.GetCurrentBranch($this.Repo.FullPath)
        
        $this.ShowMessage([string]::Format($this.Context.LocalizationService.Get("Flow.Op.PushingBranch", "Pushing '{0}'..."), $current), [Constants]::ColorHint)
        
        $res = $this.GitService.Push($this.Repo.FullPath, $current)
        if ($res.Success) {
            $this.ShowMessage($this.Context.LocalizationService.Get("Status.Success", "Success!"), [Constants]::ColorSuccess)
        } else {
            $this.ShowMessage("Push failed: $($res.Output)", [Constants]::ColorError)
        }
        Start-Sleep -Milliseconds 1500
    }
    
    hidden [void] HandleCreateBranch() {
        $this.Context.Console.NewLine()
        $promptName = $this.Context.LocalizationService.Get("Flow.Prompt.EnterName", "Enter New Branch Name: ")
        $this.Context.Console.WriteColored("  $promptName", [Constants]::ColorMenuText)
        $this.Context.Console.ShowCursor()
        $newName = Read-Host
        $this.Context.Console.HideCursor()
        
        if ([string]::IsNullOrWhiteSpace($newName)) { return }
        
        $this.ShowMessage($this.Context.LocalizationService.Get("Flow.Init.Fetching", "Fetching remotes..."), [Constants]::ColorHint)
        $this.GitService.Fetch($this.Repo.FullPath) | Out-Null
        
        $remotes = $this.GitService.GetRemoteBranches($this.Repo.FullPath)
        if ($remotes.Count -eq 0) {
             $remotes = $this.GitService.GetBranches($this.Repo.FullPath)
             $titleBase = "QUICK CHANGES > SELECT LOCAL BASE"
        } else {
             $titleBase = "QUICK CHANGES > SELECT REMOTE BASE"
        }
        
        # Focus on input for better UX
        $sel = $this.ListSelector.ShowSelection($titleBase, $remotes, @{ Prompt="Base Branch"; InitialFocus=[Constants]::FocusInput })
        if ($null -eq $sel) { return }
        $baseBranch = $sel.Value.Trim()
        
        $this.ShowMessage([string]::Format($this.Context.LocalizationService.Get("Flow.Op.Creating", "Creating '{0}' from '{1}'..."), $newName, $baseBranch), [Constants]::ColorHint)
        
        $res = $this.GitService.CreateBranch($this.Repo.FullPath, $newName, $baseBranch)
        if (-not $res.Success) {
            $this.ShowMessage("Failed: $($res.Output)", [Constants]::ColorError)
            Start-Sleep -Seconds 2
            return
        }
        $this.ShowMessage($this.Context.LocalizationService.Get("Status.Success", "Success!"), [Constants]::ColorSuccess)
        
        # Branch created and checked out. 
        # Dashboard will refresh and show "Current Branch: $newName"
        # And "Push" option should appear because it's new.
        Start-Sleep -Milliseconds 500
    }

    # Commit/Stash methods remain largely same
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
        $addRes = $this.GitService.Add($this.Repo.FullPath, ".")
        if (-not $addRes.Success) {
            $this.ShowMessage("Failed: $($addRes.Output)", [Constants]::ColorError)
            Start-Sleep -Seconds 2
            return
        }
        $res = $this.GitService.Commit($this.Repo.FullPath, $message)
        if ($res.Success) {
            $this.ShowMessage($this.Context.LocalizationService.Get("Status.Success", "Success!"), [Constants]::ColorSuccess)
        } else {
            $this.ShowMessage("Failed: $($res.Output)", [Constants]::ColorError)
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
            $this.ShowMessage("Failed: $($res.Output)", [Constants]::ColorError)
        }
        Start-Sleep -Milliseconds 1000
    }
    
    hidden [void] ShowMessage([string]$text, [ConsoleColor]$color) {
        $this.Context.Console.WriteLineColored("  $text", $color)
    }
}
