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
        while ($true) {
            $hasChanges = $this.GitService.HasUncommittedChanges($this.Repo.FullPath)
            
            $title = $this.Context.LocalizationService.Get("Flow.Quick.Title", "QUICK CHANGES DASHBOARD")
            
            $statusText = if ($hasChanges) { 
                $this.Context.LocalizationService.Get("Flow.Quick.Status.Dirty", "Status: Uncommitted changes detected")
            } else {
                $this.Context.LocalizationService.Get("Flow.Quick.Status.Clean", "Status: Working directory clean") 
            }
            
            $options = @()
            
            # 1. Dirty Actions
            if ($hasChanges) {
                $optCommit = $this.Context.LocalizationService.Get("Flow.Quick.Opt.Commit", "Commit Changes")
                $optStash = $this.Context.LocalizationService.Get("Flow.Quick.Opt.Stash", "Stash Changes")
                $options += @{ DisplayText = $optCommit; Value = "Commit" }
                $options += @{ DisplayText = $optStash; Value = "Stash" }
            }
            
            # 2. Common Actions (Branching)
            $optCreate = $this.Context.LocalizationService.Get("Flow.Quick.Opt.CreateBranch", "Create New Branch")
            $optPush = $this.Context.LocalizationService.Get("Flow.Quick.Opt.PushBranch", "Push Local Branch")
            $options += @{ DisplayText = $optCreate; Value = "CreateBranch" }
            $options += @{ DisplayText = $optPush; Value = "PushBranch" }
            
            # 3. Navigation
            $optBack = $this.Context.LocalizationService.Get("Flow.Quick.Back", "Back to Menu")
            $options += @{ DisplayText = $optBack; Value = "Back" }
            
            # Cancel text is now just a hint since we have explicit Back
            $hintText = $this.Context.LocalizationService.Get("Msg.SelectOption", "Select an option")
            
            $selection = $this.Context.OptionSelector.ShowSelection($title, $options, $null, $hintText, $false, $statusText, $true)
            
            if ($null -eq $selection -or $selection -eq "Back") {
                return $this.Context.LocalizationService.Get("Msg.ActionCancelled", "Operation cancelled.")
            }
            
            switch ($selection) {
                "Commit"       { $this.HandleCommit() }
                "Stash"        { $this.HandleStash() }
                "CreateBranch" { $this.HandleCreateBranch() }
                "PushBranch"   { $this.HandlePushBranch() }
            }
        }
        return ""
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
        
        $addRes = $this.GitService.Add($this.Repo.FullPath, ".")
        if (-not $addRes.Success) {
            $this.ShowMessage("Failed to stage files: $($addRes.Output)", [Constants]::ColorError)
            Start-Sleep -Seconds 2
            return
        }
        
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
    
    hidden [void] HandleCreateBranch() {
        # 1. Ask Name
        $this.Context.Console.NewLine()
        $promptName = $this.Context.LocalizationService.Get("Flow.Prompt.EnterName", "Enter New Branch Name: ")
        $this.Context.Console.WriteColored("  $promptName", [Constants]::ColorMenuText)
        $this.Context.Console.ShowCursor()
        $newName = Read-Host
        $this.Context.Console.HideCursor()
        
        if ([string]::IsNullOrWhiteSpace($newName)) { return }
        
        # 2. Fetch for Remote Bases
        $this.ShowMessage($this.Context.LocalizationService.Get("Flow.Init.Fetching", "Fetching remotes..."), [Constants]::ColorHint)
        $this.GitService.Fetch($this.Repo.FullPath) | Out-Null
        
        # 3. Select Base (Remote)
        $remotes = $this.GitService.GetRemoteBranches($this.Repo.FullPath)
        if ($remotes.Count -eq 0) {
             # Fallback to local if no remotes
             $remotes = $this.GitService.GetBranches($this.Repo.FullPath)
        }
        
        $titleBase = $this.Context.LocalizationService.Get("Flow.Action.SetTarget", "Select REMOTE Base Branch")
        $sel = $this.ListSelector.ShowSelection($titleBase, $remotes, @{ Prompt="Base Branch" })
        if ($null -eq $sel) { return }
        $baseBranch = $sel.Value.Trim()
        
        # 4. Create
        $this.ShowMessage([string]::Format($this.Context.LocalizationService.Get("Flow.Op.Creating", "Creating '{0}' from '{1}'..."), $newName, $baseBranch), [Constants]::ColorHint)
        
        $res = $this.GitService.CreateBranch($this.Repo.FullPath, $newName, $baseBranch)
        if (-not $res.Success) {
            $this.ShowMessage("Failed: $($res.Output)", [Constants]::ColorError)
            Start-Sleep -Seconds 2
            return
        }
        $this.ShowMessage($this.Context.LocalizationService.Get("Status.Success", "Success!"), [Constants]::ColorSuccess)
        
        # 5. Push?
        $promptPush = $this.Context.LocalizationService.Get("Flow.Prompt.PushNow", "Push new branch to origin?")
        if ($this.Context.OptionSelector.SelectYesNo($promptPush)) {
             $this.ShowMessage($this.Context.LocalizationService.Get("Flow.Status.Pushing", "Pushing to origin..."), [Constants]::ColorHint)
             $pushRes = $this.GitService.Push($this.Repo.FullPath, $newName)
             if ($pushRes.Success) {
                 $this.ShowMessage($this.Context.LocalizationService.Get("Status.Success", "Success!"), [Constants]::ColorSuccess)
             } else {
                 $this.ShowMessage("Push failed: $($pushRes.Output)", [Constants]::ColorError)
             }
             Start-Sleep -Milliseconds 1000
        }
    }
    
    hidden [void] HandlePushBranch() {
        # 1. Select Local Branch
        $locals = $this.GitService.GetBranches($this.Repo.FullPath)
        $current = $this.GitService.GetCurrentBranch($this.Repo.FullPath)
        
        $title = $this.Context.LocalizationService.Get("Flow.Quick.Opt.PushBranch", "Push Local Branch")
        $sel = $this.ListSelector.ShowSelection($title, $locals, @{ Prompt="Branch to Push"; CurrentItem=$current })
        if ($null -eq $sel) { return }
        $branchToPush = $sel.Value.Trim()
        
        # 2. Push
        $this.ShowMessage([string]::Format($this.Context.LocalizationService.Get("Flow.Op.PushingBranch", "Pushing '{0}'..."), $branchToPush), [Constants]::ColorHint)
        
        $res = $this.GitService.Push($this.Repo.FullPath, $branchToPush)
        if ($res.Success) {
            $this.ShowMessage($this.Context.LocalizationService.Get("Status.Success", "Success!"), [Constants]::ColorSuccess)
        } else {
            $this.ShowMessage("Push failed: $($res.Output)", [Constants]::ColorError)
        }
        Start-Sleep -Milliseconds 1500
    }
    
    hidden [void] ShowMessage([string]$text, [ConsoleColor]$color) {
        $this.Context.Console.WriteLineColored("  $text", $color)
    }
}
