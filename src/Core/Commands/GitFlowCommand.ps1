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
                        $integrationResult = $this.InvokeIntegrationFlow($context, $repo, $gitService, $selector)
                        # After flow, show result
                        $statusMessage = $integrationResult
                        if ($statusMessage -match "^Error") {
                             $statusColor = [Constants]::ColorError
                        } elseif ($statusMessage -eq "Integration Cancelled") {
                             $statusColor = [Constants]::ColorWarning
                        } else {
                             $statusColor = [Constants]::ColorSuccess
                        }
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

    hidden [string] InvokeIntegrationFlow($context, $repo, $gitService, $selector) {
        $flowRenderer = [IntegrationFlowRenderer]::new($context.Console, $context.Renderer, $context.LocalizationService)
        
        # 1. Fetch Remotes (Initial Setup)
        $context.Console.ClearScreen()
        $title = $context.LocalizationService.Get("Flow.Init.Title", "INTEGRATION FLOW: INITIALIZING")
        $context.Renderer.RenderHeader($title)
        $context.Console.NewLine()
        $msgFetch = $context.LocalizationService.Get("Flow.Init.Fetching", "Fetching remotes...")
        $context.Console.WriteColored("  $msgFetch", [Constants]::ColorMenuText)
        $fetchRes = $gitService.Fetch($repo.FullPath)
        if ($fetchRes.Success) {
            $context.Console.WriteLineColored(" DONE", [Constants]::ColorSuccess)
        } else {
            $msgFail = $context.LocalizationService.Get("Flow.Warning.FetchFailed", "WARNING: Fetch failed")
            $context.Console.WriteLineColored(" $msgFail", [Constants]::ColorWarning)
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
        $selectedIndex = 0
        
        while ($true) {
            $context.Console.ClearScreen()
            $flowRenderer.RenderInteractiveDashboard($flowState, $selectedIndex)
            
            $canExecute = $flowState.TargetBranchValid -and $flowState.NewBranchNameValid -and $flowState.SourceBranchValid
            $maxIndex = if ($canExecute) { 4 } else { 3 }
            
            # Input Handling
            $key = $context.Console.ReadKey()
            $keyCode = $key.VirtualKeyCode
            
            # Navigation
            if ($keyCode -eq [Constants]::KEY_UP_ARROW) {
                if ($selectedIndex -gt 0) { $selectedIndex-- }
                else { $selectedIndex = $maxIndex }
                continue
            }
            if ($keyCode -eq [Constants]::KEY_DOWN_ARROW) {
                if ($selectedIndex -lt $maxIndex) { $selectedIndex++ }
                else { $selectedIndex = 0 }
                continue
            }
            
            # Cancel/Exit
            if ($keyCode -eq [Constants]::KEY_Q -or $keyCode -eq [Constants]::KEY_ESC) {
                return $context.LocalizationService.Get("Flow.Status.Cancelled", "Integration Cancelled")
            }
            
            # Selection/Action
            if ($keyCode -eq [Constants]::KEY_ENTER) {
                $action = ""
                
                # Mapper logic
                # 0: Target, 1: Name, 2: Source
                # If canExecute: 3=Execute, 4=Exit
                # Else: 3=Exit
                
                if ($selectedIndex -eq 0) { $action = "SetTarget" }
                elseif ($selectedIndex -eq 1) { $action = "SetName" }
                elseif ($selectedIndex -eq 2) { $action = "SetSource" }
                elseif ($canExecute -and $selectedIndex -eq 3) { $action = "Execute" }
                else { return $context.LocalizationService.Get("Flow.Status.Cancelled", "Integration Cancelled") } # Exit/Cancel case
                
                switch ($action) {
                    "SetTarget" {
                        if ($null -eq $remoteBranches) {
                            $msgLoad = $context.LocalizationService.Get("Flow.Status.LoadingRemotes", "Loading remote branches...")
                            $context.Console.WriteColored($msgLoad, [Constants]::ColorHint)
                            $remoteBranches = $gitService.GetRemoteBranches($repo.FullPath)
                        }
                        # Use selector for submenu
                        $title = $context.LocalizationService.Get("Flow.Action.SetTarget", "Select TARGET Branch")
                        $prompt = $context.LocalizationService.Get("Flow.Prompt.RemoteBranch", "Select Remote Branch")
                        $sel = $selector.ShowSelection($title, $remoteBranches, @{ Prompt=$prompt; InitialFocus=[Constants]::FocusInput })
                        if ($null -ne $sel -and $sel.Type -eq "Item") {
                            $flowState.TargetBranch = "$($sel.Value)".Trim()
                            $flowState.TargetBranchValid = $true
                        }
                    }
                    "SetName" {
                        $context.Console.NewLine()
                        $prompt = $context.LocalizationService.Get("Flow.Prompt.EnterName", "Enter New Branch Name: ")
                        $context.Console.WriteColored("  $prompt", [Constants]::ColorMenuText)
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
                        $title = $context.LocalizationService.Get("Flow.Action.SetSource", "Select SOURCE Branch")
                        $prompt = $context.LocalizationService.Get("Flow.Prompt.LocalBranch", "Select Local Branch")
                        $sel = $selector.ShowSelection($title, $localBranches, @{ Prompt=$prompt; CurrentItem=$flowState.SourceBranch; InitialFocus=[Constants]::FocusInput })
                        if ($null -ne $sel -and $sel.Type -eq "Item") {
                            $flowState.SourceBranch = "$($sel.Value)".Trim()
                            $flowState.SourceBranchValid = $true
                        }
                    }
                    "Execute" {
                        $result = $this.PerformIntegration($context, $repo, $gitService, $flowState)
                        if ($result.Success) {
                           return $result.Message
                        }
                        
                        # Failure Case
                        $context.Console.NewLine()
                        $msgPress = $context.LocalizationService.Get("Flow.Status.PressAnyKey", "Press any key to return to menu...")
                        $context.Console.WriteLineColored($msgPress, [Constants]::ColorMenuText)
                        $context.Console.ReadKey()
                        return "Error: " + $result.Message
                    }
                }
            }
        }
        return $context.LocalizationService.Get("Flow.Status.Cancelled", "Integration Cancelled")
    }

    hidden [hashtable] PerformIntegration($context, $repo, $gitService, $flowState) {
        $newBranchName = $flowState.NewBranchName
        $targetBranch = $flowState.TargetBranch
        $sourceBranch = $flowState.SourceBranch
        
        $context.Console.ClearScreen()
        $title = $context.LocalizationService.Get("Flow.Dashboard.Execute", "EXECUTING INTEGRATION")
        $context.Renderer.RenderHeader($title)
        $context.Console.NewLine()
        
        # 1. Create Branch from Target
        $fmtCreate = $context.LocalizationService.Get("Flow.Op.Creating", "Creating '{0}' from '{1}'...")
        $msgCreate = [string]::Format($fmtCreate, $newBranchName, $targetBranch)
        $context.Console.WriteColored("  $msgCreate", [Constants]::ColorHint)
        
        $createRes = $gitService.CreateBranch($repo.FullPath, $newBranchName, $targetBranch)
        if (-not $createRes.Success) {
             $context.Console.WriteLineColored(" FAILED", [Constants]::ColorError)
             $context.Console.WriteLineColored("  $($createRes.Output)", [Constants]::ColorError)
             
             $fmtErr = $context.LocalizationService.Get("Flow.Error.CreateFailed", "Failed to create branch '{0}': {1}")
             $err = [string]::Format($fmtErr, $newBranchName, $createRes.Output)
             return @{ Success = $false; Message = $err }
        }
        $context.Console.WriteLineColored(" DONE", [Constants]::ColorSuccess)
        
        # 2. Merge Source
        $fmtMerge = $context.LocalizationService.Get("Flow.Op.Merging", "Merging '{0}'...")
        $msgMerge = [string]::Format($fmtMerge, $sourceBranch)
        $context.Console.WriteColored("  $msgMerge", [Constants]::ColorHint)
        
        $mergeRes = $gitService.Merge($repo.FullPath, $sourceBranch)
        if (-not $mergeRes.Success) {
             $context.Console.WriteLineColored(" FAILED", [Constants]::ColorError)
             $context.Console.WriteLineColored("  $($mergeRes.Output)", [Constants]::ColorError)
             if ($mergeRes.Output -match "CONFLICT") {
                 $msgConflict = $context.LocalizationService.Get("Flow.Error.Conflict", "Please resolve conflicts in IDE.")
                 $context.Console.WriteLineColored("  [!] $msgConflict", [Constants]::ColorWarning)
             }
             $fmtErr = $context.LocalizationService.Get("Flow.Error.MergeFailed", "Merge failed: {0}")
             $err = [string]::Format($fmtErr, $mergeRes.Output)
             return @{ Success = $false; Message = $err }
        }
        $context.Console.WriteLineColored(" DONE", [Constants]::ColorSuccess)

        # 3. Version Check Step
        $npmService = $context.RepoManager.NpmService
        if ($npmService.HasPackageJson($repo.FullPath)) {
             $currentVersion = $npmService.GetVersion($repo.FullPath)
             
             $promptTitle = $context.LocalizationService.Get("Flow.UpdateVersionPrompt", "Do you want to update the version?")
             $fmtV = $context.LocalizationService.Get("Flow.CurrentVersion", "Current Version: {0}")
             $desc = [string]::Format($fmtV, $currentVersion)
             
             $yesText = $context.LocalizationService.Get("Prompt.Yes", "Yes")
             $noText = $context.LocalizationService.Get("Prompt.No", "No")
             $cancelText = $context.LocalizationService.Get("Prompt.Cancel", "Cancel")
             
             $yesNoOptions = @(
                 @{ DisplayText = $yesText; Value = $true },
                 @{ DisplayText = $noText;  Value = $false }
             )
             
             # Pass $true for clearScreen explicitly
             $updateChoice = $context.OptionSelector.ShowSelection($promptTitle, $yesNoOptions, $false, $cancelText, $false, $desc, $true)
             
             if ($true -eq $updateChoice) {
                 $context.Console.NewLine()
                 $enterPrompt = $context.LocalizationService.Get("Flow.EnterNewVersion", "Enter new version: ")
                 $context.Console.WriteColored("  $enterPrompt", [Constants]::ColorMenuText)
                 $context.Console.ShowCursor()
                 $newVersion = Read-Host
                 $context.Console.HideCursor()
                 
                 if (-not [string]::IsNullOrWhiteSpace($newVersion)) {
                     $msgUpdating = $context.LocalizationService.Get("Flow.UpdatingVersion", "Updating version...")
                     $context.Console.WriteColored("  $msgUpdating", [Constants]::ColorHint)
                     $setRes = $npmService.SetVersion($repo.FullPath, $newVersion)
                     
                     if ($setRes.Success) {
                         $context.Console.WriteLineColored(" DONE", [Constants]::ColorSuccess)
                         
                         $msgCommitting = $context.LocalizationService.Get("Flow.CommitVersionBump", "Committing version bump...")
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
        $msgPush = $context.LocalizationService.Get("Flow.Status.Pushing", "Pushing to origin...")
        $context.Console.WriteColored("  $msgPush", [Constants]::ColorHint)
        $pushRes = $gitService.Push($repo.FullPath, $newBranchName)
        if (-not $pushRes.Success) {
             $context.Console.WriteLineColored(" FAILED", [Constants]::ColorError)
             $context.Console.WriteLineColored("  $($pushRes.Output)", [Constants]::ColorError)
             
             $fmtErr = $context.LocalizationService.Get("Flow.Error.PushFailed", "Push failed: {0}")
             $err = [string]::Format($fmtErr, $pushRes.Output)
             return @{ Success = $false; Message = $err }
        }
        $context.Console.WriteLineColored(" DONE", [Constants]::ColorSuccess)
        
        # 5. PR URL
        $msgCheck = $context.LocalizationService.Get("Flow.Status.CheckingPR", "Checking PR capability...")
        $context.Console.WriteColored("  $msgCheck", [Constants]::ColorHint)
        $repoUrl = $gitService.GetRepoUrl($repo.FullPath)
        
        if (-not [string]::IsNullOrWhiteSpace($repoUrl)) {
            $context.Console.WriteLineColored(" DONE", [Constants]::ColorSuccess)
            $prUrl = "{0}/compare/{1}?expand=1" -f $repoUrl, $newBranchName
            
            $context.Console.NewLine()
            $promptPr = $context.LocalizationService.Get("Flow.OpenPrPrompt", "Open Pull Request on GitHub?")
            $openPr = $context.OptionSelector.SelectYesNo($promptPr)
            if ($openPr) {
                Start-Process $prUrl
            }
        } else {
            $context.Console.WriteLineColored(" SKIP (No URL)", [Constants]::ColorWarning)
            $context.Console.NewLine()
            $msgNoUrl = $context.LocalizationService.Get("Flow.Error.PrUrlNotFound", "[i] Could not determine Pull Request URL.")
            $context.Console.WriteLineColored("  $msgNoUrl", [Constants]::ColorHint)
        }
        
        $msgDone = $context.LocalizationService.Get("Flow.Status.Completed", "Integration Flow Completed.")
        return @{ Success = $true; Message = $msgDone }
    }
}
