
class QuickChangeFlowController : FlowControllerBase {
    [FilteredListSelector] $ListSelector
    
    QuickChangeFlowController([CommandContext]$context, [object]$repo) : base($context, $repo) {
        $this.ListSelector = [FilteredListSelector]::new($context.Console, $context.Renderer)
    }
    
    [string] Start() {
        $tempMessage = ""
        $tempMessageColor = [Constants]::ColorWarning
        
        while ($true) {
            # 1. State
            $hasChanges = $this.GitReadService.HasUncommittedChanges($this.Repo.FullPath)
            $currentBranch = $this.GitReadService.GetCurrentBranch($this.Repo.FullPath)
            $remoteUrl = $this.GitReadService.GetRemoteUrl($this.Repo.FullPath)
            $hasRemote = -not [string]::IsNullOrWhiteSpace($remoteUrl)
            
            # 2. Logic for Push / Pull
            $needsPush = $false
            $needsPull = $false
            
            if ($hasRemote) {
                # Note: GitWriteService or ReadService for GetRemoteBranches? ReadService.
                $remotes = $this.GitReadService.GetRemoteBranches($this.Repo.FullPath)
                $target = "origin/$currentBranch"
                $existsOnRemote = $remotes -contains $target
                
                if (-not $existsOnRemote) {
                    $needsPush = $true # New branch
                } elseif ($this.GitReadService.HasUnpushedCommits($this.Repo.FullPath)) {
                    $needsPush = $true # Ahead
                }
                
                # Check Pull Status
                $tracking = $this.GitReadService.GetBranchTrackingStatus($this.Repo.FullPath, $currentBranch)
                if ($tracking.Behind -gt 0) {
                    $needsPull = $true
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
            
            # OPT 2: Push / Pull (Contextual)
            if ($needsPush) {
                $lblPush = $this.Context.LocalizationService.Get("Flow.Quick.Opt.PushBranch", "Push Local Branch")
                $options += @{ DisplayText = "  $lblPush"; Value = "PushBranch" }
            }
            if ($needsPull) {
                $lblPull = $this.Context.LocalizationService.Get("Flow.Action.Pull", "Pull")
                $options += @{ DisplayText = "  $lblPull"; Value = "PullBranch" }
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
            
            $optDelete = $this.Context.LocalizationService.Get("Flow.Quick.Opt.Delete", "Delete Branch...")
            $options += @{ DisplayText = $optDelete; Value = "DeleteBranch" }
            
            $optDeleteRemote = $this.Context.LocalizationService.Get("Flow.Quick.Opt.DeleteRemoteOnly", "Delete Remote Branch Only...")
            $options += @{ DisplayText = $optDeleteRemote; Value = "DeleteRemoteOnly" }
            
            # OPT 5: Back
            $optBack = $this.Context.LocalizationService.Get("Flow.Quick.Back", "Back to Menu")
            $options += @{ DisplayText = $optBack; Value = "Back" }
            
            $hintText = $this.Context.LocalizationService.Get("Msg.SelectOption", "Select an option")
            
            # Pass $tempMessage as description if set
            $desc = if ($tempMessage) { $tempMessage } else { $statusText }
            # Use Red for error warnings (tempMessage), otherwise standard color for status
            $descColor = if ($tempMessage) { $tempMessageColor } else { [Constants]::ColorWarning } 
            
            # Override for status text color if not an error message
            if (-not $tempMessage) {
                 if ($hasChanges) { $descColor = [Constants]::ColorWarning } else { $descColor = [ConsoleColor]::Gray }
            }
            
            $config = [SelectionOptions]::new()
            $config.Title = $title
            $config.Options = $options
            $config.CancelText = $hintText
            $config.ShowCurrentMarker = $false
            $config.Description = $desc
            $config.DescriptionColor = $descColor
            $selection = $this.Context.OptionSelector.Show($config)
            
            # Clear temporary message after showing once
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
                "PushBranch"        { $this.HandlePushBranch() }
                "PullBranch"        { $this.HandlePullBranch() }
                "Commit"            { $this.HandleCommit() }
                "Stash"             { $this.HandleStash() }
                "CreateBranch"      { $this.HandleCreateBranch() }
                "DeleteBranch"      { $this.HandleDeleteBranch() }
                "DeleteRemoteOnly"  { $this.HandleDeleteRemoteOnly() }
            }
        }
        return ""
    }

    # ... existing handlers ...

    hidden [bool] Confirm([string]$title, [string]$prompt) {
        $options = @(
            @{ DisplayText = "Yes"; Value = "Yes" },
            @{ DisplayText = "No";  Value = "No" }
        )
        
        $config = [SelectionOptions]::new()
        $config.Title = $title
        $config.Options = $options
        $config.Description = $prompt
        $config.DescriptionColor = [Constants]::ColorWarning
        
        $selection = $this.Context.OptionSelector.Show($config)
        return $selection -eq "Yes"
    }

    hidden [void] HandleDeleteRemoteOnly() {
        $this.ShowMessage($this.Context.LocalizationService.Get("Flow.Init.Fetching", "Fetching remotes..."), [Constants]::ColorHint)
        $this.GitWriteService.Fetch($this.Repo.FullPath) | Out-Null
        
        # 1. Select Remote Branch to Delete
        $remotes = $this.GitReadService.GetRemoteBranches($this.Repo.FullPath)
        
        if ($null -eq $remotes -or $remotes.Count -eq 0) {
            $this.ShowMessage($this.Context.LocalizationService.Get("Flow.Error.NoBranches", "No branches found"), [Constants]::ColorWarning)
            Start-Sleep -Seconds 1
            return
        }

        $title = "DELETE REMOTE BRANCH ONLY"
        $sel = $this.ListSelector.ShowSelection($title, $remotes, @{ Prompt="Select Remote Branch to Delete"; InitialFocus=[Constants]::FocusInput })
        
        if ($null -eq $sel) { return }
        
        $selectedRemote = $sel.Value.Trim()
        # Strip "origin/" prefix if present to get clean branch name
        $cleanBranchName = $selectedRemote -replace "^origin/", ""
        
        # 2. Remote Delete Prompt
        $promptRemote = $this.Context.LocalizationService.Get("Flow.Prompt.DeleteRemote", "Delete remote branch 'origin/{0}'? (IRREVERSIBLE)") -f $cleanBranchName
        if ($this.Confirm("DELETE REMOTE ONLY?", $promptRemote)) {
             $this.ShowMessage("Deleting remote branch...", [Constants]::ColorWarning)
             $remRes = $this.GitWriteService.DeleteRemoteBranch($this.Repo.FullPath, $cleanBranchName)
             if ($remRes.Success) {
                 $msgRem = $this.Context.LocalizationService.Get("Flow.Status.RemoteDeleted", "Remote branch 'origin/{0}' deleted.") -f $cleanBranchName
                 $this.ShowMessage($msgRem, [Constants]::ColorSuccess)
             } else {
                 $this.ShowMessage("Remote Delete Failed: $($remRes.Output)", [Constants]::ColorError)
             }
             Start-Sleep -Seconds 1
        }
        Start-Sleep -Milliseconds 500
    }
    
    hidden [string] HandleSwitchBranch([bool]$hasChanges) {
        if ($hasChanges) {
            return $this.Context.LocalizationService.Get("Flow.Warning.DirtySwitch", "Running changes! Commit or stash before switching branches.")
        }
        
        $branches = $this.GitReadService.GetBranches($this.Repo.FullPath)
        $current = $this.GitReadService.GetCurrentBranch($this.Repo.FullPath)
        
        $title = "QUICK CHANGES > SWITCH BRANCH"
        $sel = $this.ListSelector.ShowSelection($title, $branches, @{ Prompt="Select Branch"; CurrentItem=$current; InitialFocus=[Constants]::FocusInput })
        
        if ($null -ne $sel) {
            $target = $sel.Value.Trim()
            if ($target -ne $current) {
                $this.ShowMessage("Checking out '$target'...", [Constants]::ColorHint)
                # Checkout -> WriteService
                $res = $this.GitWriteService.Checkout($this.Repo.FullPath, $target)
                if (-not $res.Success) {
                     $this.ShowMessage("Error: $($res.Output)", [Constants]::ColorError)
                     Start-Sleep -Seconds 2
                }
            }
        }
        return ""
    }
    
    hidden [void] HandlePushBranch() {
        $current = $this.GitReadService.GetCurrentBranch($this.Repo.FullPath)
        
        $this.ShowMessage([string]::Format($this.Context.LocalizationService.Get("Flow.Op.PushingBranch", "Pushing '{0}'..."), $current), [Constants]::ColorHint)
        
        # Push -> WriteService
        $res = $this.GitWriteService.Push($this.Repo.FullPath, $current)
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
        # Fetch -> WriteService
        $this.GitWriteService.Fetch($this.Repo.FullPath) | Out-Null
        
        $remotes = $this.GitReadService.GetRemoteBranches($this.Repo.FullPath)
        if ($remotes.Count -eq 0) {
             # GetBranches -> ReadService
             $remotes = $this.GitReadService.GetBranches($this.Repo.FullPath)
             $titleBase = "QUICK CHANGES > SELECT LOCAL BASE"
        } else {
             $titleBase = "QUICK CHANGES > SELECT REMOTE BASE"
        }
        
        # Focus on input for better UX
        $sel = $this.ListSelector.ShowSelection($titleBase, $remotes, @{ Prompt="Base Branch"; InitialFocus=[Constants]::FocusInput })
        if ($null -eq $sel) { return }
        $baseBranch = $sel.Value.Trim()
        
        $this.ShowMessage([string]::Format($this.Context.LocalizationService.Get("Flow.Op.Creating", "Creating '{0}' from '{1}'..."), $newName, $baseBranch), [Constants]::ColorHint)
        
        # CreateBranch -> WriteService
        $res = $this.GitWriteService.CreateBranch($this.Repo.FullPath, $newName, $baseBranch)
        if (-not $res.Success) {
            $this.ShowMessage("Failed: $($res.Output)", [Constants]::ColorError)
            Start-Sleep -Seconds 2
            return
        }
        $this.ShowMessage($this.Context.LocalizationService.Get("Status.Success", "Success!"), [Constants]::ColorSuccess)
        
        Start-Sleep -Milliseconds 500
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
        # Add -> WriteService
        $addRes = $this.GitWriteService.Add($this.Repo.FullPath, ".")
        if (-not $addRes.Success) {
            $this.ShowMessage("Failed: $($addRes.Output)", [Constants]::ColorError)
            Start-Sleep -Seconds 2
            return
        }
        # Commit -> WriteService
        $res = $this.GitWriteService.Commit($this.Repo.FullPath, $message)
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
        # Stash -> WriteService
        $res = $this.GitWriteService.Stash($this.Repo.FullPath, $name)
        if ($res.Success) {
            $this.ShowMessage($this.Context.LocalizationService.Get("Status.Success", "Success!"), [Constants]::ColorSuccess)
        } else {
            $this.ShowMessage("Failed: $($res.Output)", [Constants]::ColorError)
        }
        Start-Sleep -Milliseconds 1000
    }

    hidden [void] HandlePullBranch() {
        $this.ShowMessage("Pulling updates...", [Constants]::ColorHint)
        $res = $this.GitWriteService.Pull($this.Repo.FullPath)
        if ($res.Success) {
            $this.ShowMessage($this.Context.LocalizationService.Get("Status.Success", "Success!"), [Constants]::ColorSuccess)
        } else {
             $this.ShowMessage("Pull Failed: $($res.Output)", [Constants]::ColorError)
             Start-Sleep -Seconds 2
        }
        Start-Sleep -Milliseconds 1000
    }

    hidden [void] HandleDeleteBranch() {
        # 1. Select Branch to Delete (exclude current)
        $branches = $this.GitReadService.GetBranches($this.Repo.FullPath)
        $current = $this.GitReadService.GetCurrentBranch($this.Repo.FullPath)
        $filtered = $branches | Where-Object { $_ -ne $current }
        
        if ($null -eq $filtered -or $filtered.Count -eq 0) {
            $this.ShowMessage($this.Context.LocalizationService.Get("Flow.Error.NoBranches", "No branches found"), [Constants]::ColorWarning)
            Start-Sleep -Seconds 1
            return
        }

        $title = "DELETE BRANCH"
        $sel = $this.ListSelector.ShowSelection($title, $filtered, @{ Prompt="Select Branch to Delete"; InitialFocus=[Constants]::FocusInput })
        
        if ($null -eq $sel) { return }
        $branchToDelete = $sel.Value.Trim()
        
        # 2. Local Delete Prompt
        $promptLocal = $this.Context.LocalizationService.Get("Flow.Prompt.DeleteLocal", "Delete local branch '{0}'? (FORCE CAREFUL)") -f $branchToDelete
        
        if ($this.Confirm("DELETE LOCAL?", $promptLocal)) {
            $delRes = $this.GitWriteService.DeleteLocalBranch($this.Repo.FullPath, $branchToDelete, $true)
            if ($delRes.Success) {
                $msg = $this.Context.LocalizationService.Get("Flow.Status.LocalDeleted", "Local branch '{0}' deleted.") -f $branchToDelete
                $this.ShowMessage($msg, [Constants]::ColorSuccess)
                
                # 3. Remote Delete Prompt (if exists)
                # ISP FIX: Use GitReadService instead of GitService
                if ($this.GitReadService.RemoteBranchExists($this.Repo.FullPath, $branchToDelete)) {
                    $promptRemote = $this.Context.LocalizationService.Get("Flow.Prompt.DeleteRemote", "Delete remote branch 'origin/{0}'? (IRREVERSIBLE)") -f $branchToDelete
                    
                    if ($this.Confirm("DELETE REMOTE?", $promptRemote)) {
                         $this.ShowMessage("Deleting remote branch...", [Constants]::ColorWarning)
                         $remRes = $this.GitWriteService.DeleteRemoteBranch($this.Repo.FullPath, $branchToDelete)
                         if ($remRes.Success) {
                             $msgRem = $this.Context.LocalizationService.Get("Flow.Status.RemoteDeleted", "Remote branch 'origin/{0}' deleted.") -f $branchToDelete
                             $this.ShowMessage($msgRem, [Constants]::ColorSuccess)
                         } else {
                             $this.ShowMessage("Remote Delete Failed: $($remRes.Output)", [Constants]::ColorError)
                         }
                         Start-Sleep -Seconds 1
                    }
                }
            } else {
                $this.ShowMessage("Delete Failed: $($delRes.Output)", [Constants]::ColorError)
                Start-Sleep -Seconds 2
            }
        }
        Start-Sleep -Milliseconds 500
    }
}
