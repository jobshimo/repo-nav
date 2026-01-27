<#
.SYNOPSIS
    GitFlowCommand - Orchestrates the Advanced Git Flow
    
.DESCRIPTION
    Triggers the flow:
    1. Select Base Branch
    2. Create New Branch
    3. Select Branch to Merge (optional?) or merge strategy
    4. Open PR
    
    Triggered by 'B' key.
#>

class GitFlowCommand : INavigationCommand {
    
    [bool] CanExecute([object]$keyPress, [CommandContext]$context) {
        # 'B' for Branch/Flow
        return $keyPress.VirtualKeyCode -eq [Constants]::KEY_B
    }
    
    [string] GetLoc([CommandContext]$context, [string]$key, [string]$default) {
        if ($null -ne $context.LocalizationService) {
            return $context.LocalizationService.Get($key)
        }
        return $default
    }

    [void] Execute([object]$keyPress, [CommandContext]$context) {
        $state = $context.State
        $repos = $state.GetRepositories()
        $currentIndex = $state.GetCurrentIndex()
        
        if ($currentIndex -ge $repos.Count) {
             return
        }
        
        $repo = $repos[$currentIndex]
        if ($null -eq $repo) {
            return
        }
        
        $gitService = $context.RepoManager.GitService
        
        # Stop navigation loop for interaction
        $state.Stop()
        
        try {
            if (-not $gitService.IsGitRepository($repo.FullPath)) {
                 $context.Console.WriteError($this.GetLoc($context, "UI.NoGit", "Not a git repository"))
                 Start-Sleep -Milliseconds 1000
                 return
            }
            
            # 1. Select Base Branch
            $selector = [FilteredListSelector]::new($context.Console, $context.Renderer)
            
            # Persistent loop for the menu
            $loop = $true
            # Persist last selected index to restore position
            $lastIndex = 0
            # Status from previous action
            $statusMessage = $null
            $statusColor = [ConsoleColor]::Gray
            
            while ($loop) {
                $branches = $gitService.GetBranches($repo.FullPath)
                if ($branches.Count -eq 0) {
                    $context.Console.WriteError("No branches found") 
                    Start-Sleep -Milliseconds 1000
                    return
                }
                
                # Select Base Branch OR Switch Branch
                $selectBaseTitle = $this.GetLoc($context, "Flow.SelectBase", "SELECT BRANCH")
                $selectBasePrompt = $this.GetLoc($context, "Flow.SelectBasePrompt", "From Branch")
                
                # Header Options (Defined closer to usage or in a constant if shared)
                $flowOptions = @("Integrate", "flow2", "flow3")
                
                # Current Branch Info
                $currentBranch = $gitService.GetCurrentBranch($repo.FullPath)
                $currentMarker = "({0})" -f $this.GetLoc($context, "UI.Current", "current")
                
                # Prepare Options for Selector
                $selectorOptions = @{
                    Prompt        = $selectBasePrompt
                    HeaderOptions = $flowOptions
                    CurrentItem   = $currentBranch
                    CurrentMarker = $currentMarker
                    InitialIndex  = $lastIndex
                    StatusMessage = $statusMessage
                    StatusColor   = $statusColor
                    InitialFocus  = [Constants]::FocusInput
                }
                
                # The selector now returns a hashtable: @{ Type=...; Value=...; Index=... }
                $selection = $selector.ShowSelection($selectBaseTitle, $branches, $selectorOptions)
                
                # Clear status after showing it once
                $statusMessage = $null
                $statusColor = [ConsoleColor]::Gray
                
                if ($null -eq $selection) { break } # Cancelled (Esc)
                
                if ($selection.Type -eq "Item") {
                    $selectedBranch = $selection.Value
                    $lastIndex = $selection.Index # Restore this index next time
                    
                    if ($selectedBranch -eq $currentBranch) {
                        # No op if already on that branch
                        continue 
                    }
                    
                    # Logic to switch branch (Checkout)
                    # Check for uncommitted changes first
                    $hasChanges = $gitService.HasUncommittedChanges($repo.FullPath)
                    
                    if ($hasChanges) {
                        $statusMessage = "Error: Cannot checkout '$selectedBranch'. You have uncommitted changes."
                        $statusColor = [Constants]::ColorError
                    } else {
                        $result = $gitService.Checkout($repo.FullPath, $selectedBranch)
                        if ($result.Success) {
                            $statusMessage = "Checked out '$selectedBranch' successfully."
                            $statusColor = [Constants]::ColorSuccess
                        } else {
                             # Clean up error message if possible
                             $err = if ($result.Output) { $result.Output } else { "Unknown error" }
                             $statusMessage = "Error: $err"
                             $statusColor = [Constants]::ColorError
                        }
                    }
                }
                elseif ($selection.Type -eq "Header") {
                    $flow = $selection.Value
                    if ($flow -eq "Integrate") {
                        $this.InvokeIntegrationFlow($context, $repo, $gitService, $selector)
                        # After flow, we might want to refresh branches list or status
                        $statusMessage = "Integration Flow Completed."
                        $statusColor = [Constants]::ColorSuccess
                    } else {
                        $statusMessage = "Selected Flow: $flow (Not implemented)"
                        $statusColor = [Constants]::ColorWarning
                    }
                }
            }
            
        }
        finally {
             # Resume navigation and force redraw
             $state.Resume()
             $state.MarkForFullRedraw()
        }
    }

    hidden [void] InvokeIntegrationFlow($context, $repo, $gitService, $selector) {
        $flowRenderer = [IntegrationFlowRenderer]::new($context.Console, $context.Renderer)
        
        # 1. Fetch Remotes (Initial Setup)
        $context.Console.ClearScreen()
        $context.Renderer.RenderHeader("INTEGRATION FLOW: INITIALIZING")
        $context.Console.NewLine()
        $context.Console.WriteColored("  Fetching remotes...", [Constants]::ColorMenuText)
        $fetchRes = $gitService.Fetch($repo.FullPath)
        if ($fetchRes.Success) {
            $context.Console.WriteLineColored(" DONE", [Constants]::ColorSuccess)
        } else {
            $context.Console.WriteLineColored(" WARNING: Fetch failed", [Constants]::ColorWarning)
        }
        Start-Sleep -Milliseconds 300
        
        # 2. Initialize State
        $currentBranch = $gitService.GetCurrentBranch($repo.FullPath)
        $flowState = @{
            TargetBranch      = ""
            TargetBranchValid = $false
            NewBranchName     = ""
            NewBranchNameValid= $false
            SourceBranch      = ""
            SourceBranchValid = $false
        }
        
        $remoteBranches = $null # Lazy load cache

        # 3. Dashboard Loop
        while ($true) {
            $context.Console.ClearScreen()
            $flowRenderer.RenderDashboard($flowState)
            
            $canExecute = $flowState.TargetBranchValid -and $flowState.NewBranchNameValid -and $flowState.SourceBranchValid
            
            # Build Options
            $options = @()
            $options += @{ DisplayText = "1. Set Target Branch (Remote)"; Value = "SetTarget" }
            $options += @{ DisplayText = "2. Set New Branch Name";        Value = "SetName" }
            $options += @{ DisplayText = "3. Set Source Branch (Local)";  Value = "SetSource" }
            
            if ($canExecute) {
                # Add extra newline for separation before execution option
                # Logic: OptionSelector doesn't easily support separators in options array without custom logic
                $options += @{ DisplayText = "4. EXECUTE INTEGRATION";    Value = "Execute" }
            }
            
            # Add separator logic? No, just keep it simple
            $options += @{ DisplayText = "Exit / Cancel"; Value = "Cancel" }
            
            # Do NOT clear screen, so Dashboard remains visible above
            $selection = $context.OptionSelector.ShowSelection("Select Action", $options, $false, $null, $false, "", $false)
            
            if ($null -eq $selection -or $selection -eq "Cancel") {
                return
            }
            
            switch ($selection) {
                "SetTarget" {
                    if ($null -eq $remoteBranches) {
                        $context.Console.WriteColored("Loading remote branches...", [Constants]::ColorHint)
                        $remoteBranches = $gitService.GetRemoteBranches($repo.FullPath)
                    }
                    $sel = $selector.ShowSelection("Select TARGET Branch", $remoteBranches, @{ Prompt="Select Remote Branch"; InitialFocus=[Constants]::FocusInput })
                    if ($null -ne $sel -and $sel.Type -eq "Item") {
                        # Explicitly cast to string and trim to be safe
                        $flowState.TargetBranch = "$($sel.Value)".Trim()
                        $flowState.TargetBranchValid = $true
                    }
                }
                "SetName" {
                    $context.Console.NewLine()
                    $context.Console.WriteColored("  Enter New Branch Name: ", [Constants]::ColorMenuText)
                    $context.Console.ShowCursor()
                    $inputName = Read-Host
                    $context.Console.HideCursor()
                    if (-not [string]::IsNullOrWhiteSpace($inputName)) {
                        $flowState.NewBranchName = $inputName.Trim()
                        $flowState.NewBranchNameValid = $true
                    }
                }
                "SetSource" {
                    $localBranches = $gitService.GetBranches($repo.FullPath)
                    $sel = $selector.ShowSelection("Select SOURCE Branch", $localBranches, @{ Prompt="Select Local Branch"; CurrentItem=$flowState.SourceBranch; InitialFocus=[Constants]::FocusInput })
                    if ($null -ne $sel -and $sel.Type -eq "Item") {
                        $flowState.SourceBranch = "$($sel.Value)".Trim()
                        $flowState.SourceBranchValid = $true
                    }
                }
                "Execute" {
                    if ($canExecute) {
                       $success = $this.PerformIntegration($context, $repo, $gitService, $flowState)
                       if ($success) { return }
                       # If failed, pause and loop
                       $context.Console.WriteLine("Press any key to return...")
                       $context.Console.ReadKey()
                    }
                }
            }
        }
    }

    hidden [bool] PerformIntegration($context, $repo, $gitService, $flowState) {
        $newBranchName = $flowState.NewBranchName
        $targetBranch = $flowState.TargetBranch
        $sourceBranch = $flowState.SourceBranch
        
        $context.Console.ClearScreen()
        $context.Renderer.RenderHeader("EXECUTING INTEGRATION")
        $context.Console.NewLine()
        
        # 1. Create Branch from Target
        $context.Console.WriteColored("  Creating '$newBranchName' from '$targetBranch'...", [Constants]::ColorHint)
        $createRes = $gitService.CreateBranch($repo.FullPath, $newBranchName, $targetBranch)
        if (-not $createRes.Success) {
             $context.Console.WriteLineColored(" FAILED", [Constants]::ColorError)
             $context.Console.WriteLineColored("  $($createRes.Output)", [Constants]::ColorError)
             return $false
        }
        $context.Console.WriteLineColored(" DONE", [Constants]::ColorSuccess)
        
        # 2. Merge Source
        $context.Console.WriteColored("  Merging '$sourceBranch'...", [Constants]::ColorHint)
        $mergeRes = $gitService.Merge($repo.FullPath, $sourceBranch)
        if (-not $mergeRes.Success) {
             $context.Console.WriteLineColored(" FAILED", [Constants]::ColorError)
             $context.Console.WriteLineColored("  $($mergeRes.Output)", [Constants]::ColorError)
             if ($mergeRes.Output -match "CONFLICT") {
                 $context.Console.WriteLineColored("  [!] Please resolve conflicts in IDE and finish manually.", [Constants]::ColorWarning)
             }
             return $false
        }
        $context.Console.WriteLineColored(" DONE", [Constants]::ColorSuccess)

        # 3. Version Check Step
        $npmService = $context.RepoManager.NpmService
        if ($npmService.HasPackageJson($repo.FullPath)) {
             $currentVersion = $npmService.GetVersion($repo.FullPath)
             
             $currentVersion = $npmService.GetVersion($repo.FullPath)
             
             $promptTitle = $this.GetLoc($context, "Flow.UpdateVersionPrompt", "Do you want to update the version?")
             $vFmt = $this.GetLoc($context, "Flow.CurrentVersion", "Current Version: {0}")
             $desc = $vFmt -f $currentVersion
             
             $yesText = $this.GetLoc($context, "Prompt.Yes", "Yes")
             $noText = $this.GetLoc($context, "Prompt.No", "No")
             $cancelText = $this.GetLoc($context, "Prompt.Cancel", "Cancel")
             
             $yesNoOptions = @(
                 @{ DisplayText = $yesText; Value = $true },
                 @{ DisplayText = $noText;  Value = $false }
             )
             
             # Pass $true for clearScreen explicitly
             $updateChoice = $context.OptionSelector.ShowSelection($promptTitle, $yesNoOptions, $false, $cancelText, $false, $desc, $true)
             
             if ($true -eq $updateChoice) {
                 $context.Console.NewLine()
                 $enterPrompt = $this.GetLoc($context, "Flow.EnterNewVersion", "Enter new version: ")
                 $context.Console.WriteColored("  $enterPrompt", [Constants]::ColorMenuText)
                 $context.Console.ShowCursor()
                 $newVersion = Read-Host
                 $context.Console.HideCursor()
                 
                 if (-not [string]::IsNullOrWhiteSpace($newVersion)) {
                     $msgUpdating = $this.GetLoc($context, "Flow.UpdatingVersion", "Updating version...")
                     $context.Console.WriteColored("  $msgUpdating", [Constants]::ColorHint)
                     $setRes = $npmService.SetVersion($repo.FullPath, $newVersion)
                     
                     if ($setRes.Success) {
                         $context.Console.WriteLineColored(" DONE", [Constants]::ColorSuccess)
                         
                         $msgCommitting = $this.GetLoc($context, "Flow.CommitVersionBump", "Committing version bump...")
                         $context.Console.WriteColored("  $msgCommitting", [Constants]::ColorHint)
                         
                         [void]$gitService.Add($repo.FullPath, "package.json")
                         if ($npmService.HasPackageLock($repo.FullPath)) {
                             [void]$gitService.Add($repo.FullPath, "package-lock.json")
                         }
                         
                         $commitRes = $gitService.Commit($repo.FullPath, "chore: bump version to $newVersion")
                         if ($commitRes.Success) {
                             $context.Console.WriteLineColored(" DONE", [Constants]::ColorSuccess)
                         } else {
                             $context.Console.WriteLineColored(" FAILED", [Constants]::ColorError)
                             $context.Console.WriteLineColored("  Running without commit...", [Constants]::ColorWarning)
                         }
                     } else {
                         $context.Console.WriteLineColored(" FAILED", [Constants]::ColorError)
                     }
                 }
             }
        }

        # 4. Push
        $context.Console.WriteColored("  Pushing to origin...", [Constants]::ColorHint)
        $pushRes = $gitService.Push($repo.FullPath, $newBranchName)
        if (-not $pushRes.Success) {
             $context.Console.WriteLineColored(" FAILED", [Constants]::ColorError)
             $context.Console.WriteLineColored("  $($pushRes.Output)", [Constants]::ColorError)
             return $false
        }
        $context.Console.WriteLineColored(" DONE", [Constants]::ColorSuccess)
        
        # 5. PR URL
        $context.Console.WriteColored("  Checking PR capability...", [Constants]::ColorHint)
        $repoUrl = $gitService.GetRepoUrl($repo.FullPath)
        
        if (-not [string]::IsNullOrWhiteSpace($repoUrl)) {
            $context.Console.WriteLineColored(" DONE", [Constants]::ColorSuccess)
            $prUrl = "{0}/compare/{1}?expand=1" -f $repoUrl, $newBranchName
            
            $context.Console.NewLine()
            # Default behavior clears screen which is what user wants for this step
            $openPr = $context.OptionSelector.SelectYesNo("Open Pull Request in Browser?")
            if ($openPr) {
                Start-Process $prUrl
            }
        } else {
            $context.Console.WriteLineColored(" SKIP (No URL)", [Constants]::ColorWarning)
            $context.Console.NewLine()
            $context.Console.WriteLineColored("  [i] Could not determine Pull Request URL.", [Constants]::ColorHint)
        }
        
        return $true
    }
}
