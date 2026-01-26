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
        # Initialize variables to satisfy strict parser analysis
        $newBranchName = ""
        $targetBranch = ""
        $sourceBranch = ""
        
        # 1. Fetch Remotes
        $context.Console.ClearScreen()
        $context.Renderer.RenderHeader("INTEGRATION FLOW: INITIALIZING")
        $context.Console.NewLine()
        $context.Console.WriteColored("  Fetching remotes...", [Constants]::ColorMenuText)
        
        # Force redraw before blocking operation
        # (PowerShell might buffer output, but Write-Host usually flushes. 
        # Using WriteColored which wraps output, should be fine)
        
        $fetchRes = $gitService.Fetch($repo.FullPath)
        
        if (-not $fetchRes.Success) {
            $context.Console.WriteLineColored(" FAILED", [Constants]::ColorError)
            $context.Console.WriteLineColored("  $($fetchRes.Output)", [Constants]::ColorError)
            Start-Sleep -Seconds 2
            return
        }
        $context.Console.WriteLineColored(" DONE", [Constants]::ColorSuccess)
        Start-Sleep -Milliseconds 300

        # 2. Select Target Branch (Remote)
        $remoteBranches = $gitService.GetRemoteBranches($repo.FullPath)
        if ($remoteBranches.Count -eq 0) {
            $context.Console.WriteError("No remote branches found.")
            Start-Sleep -Seconds 2
            return
        }
        
        $targetOpts = @{
            Prompt = "Select TARGET (Environment) Branch"
            HeaderOptions = @()
            InitialFocus = [Constants]::FocusInput
        }
        # Passing $null as currentItem so no pre-selection or maybe 'origin/develop'?
        $targetSelection = $selector.ShowSelection("INTEGRATION FLOW: STEP 1/3", $remoteBranches, $targetOpts)
        if ($null -eq $targetSelection) { return }
        $targetBranch = $targetSelection.Value

        # 3. Input New Branch Name
        $context.Console.ClearScreen()
        $context.Renderer.RenderHeader("INTEGRATION FLOW: STEP 2/3")
        $context.Console.NewLine()
        $context.Console.WriteColored("  Target Branch: ", [Constants]::ColorLabel)
        $context.Console.WriteLineColored($targetBranch, [Constants]::ColorValue)
        $context.Console.NewLine()
        
        $context.Console.WriteColored("  Enter Name for Intermediate Branch: ", [Constants]::ColorMenuText)
        $inputName = Read-Host
        if ([string]::IsNullOrWhiteSpace($inputName)) { return }
        $newBranchName = $inputName

        # 4. Select Source Branch (Local)
        $localBranches = $gitService.GetBranches($repo.FullPath)
        $currentBranch = $gitService.GetCurrentBranch($repo.FullPath)
        
        $sourceOpts = @{
            Prompt = "Select SOURCE (Feature) Branch"
            HeaderOptions = @()
            CurrentItem = $currentBranch
            CurrentMarker = "(current)"
            InitialFocus = [Constants]::FocusInput
        }
        $sourceSelection = $selector.ShowSelection("INTEGRATION FLOW: STEP 3/3", $localBranches, $sourceOpts)
        if ($null -eq $sourceSelection) { return }
        $sourceBranch = $sourceSelection.Value

        # 5. Confirmation
        $context.Console.ClearScreen()
        $context.Renderer.RenderHeader("CONFIRM INTEGRATION")
        $context.Console.NewLine()
        $context.Console.WriteColored("  1. Create Branch: ", [Constants]::ColorLabel); $context.Console.WriteLineColored($newBranchName, [Constants]::ColorValue)
        $context.Console.WriteColored("     From (Base):   ", [Constants]::ColorLabel); $context.Console.WriteLineColored($targetBranch, [Constants]::ColorValue)
        $context.Console.WriteColored("  2. Merge Source:  ", [Constants]::ColorLabel); $context.Console.WriteLineColored($sourceBranch, [Constants]::ColorValue)
        $context.Console.WriteColored("  3. Push & PR:     ", [Constants]::ColorLabel); $context.Console.WriteLineColored("YES", [Constants]::ColorValue)
        $context.Console.NewLine()
        
        $confirm = $context.OptionSelector.SelectYesNo("Proceed with Integration?")
        if (-not $confirm) { return }

        # 6. Execution
        $context.Console.NewLine()
        
        # Create Branch from Target
        $context.Console.WriteColored("  Creating '$newBranchName' from '$targetBranch'...", [Constants]::ColorHint)
        $createRes = $gitService.CreateBranch($repo.FullPath, $newBranchName, $targetBranch)
        if (-not $createRes.Success) {
             $context.Console.WriteLineColored(" FAILED", [Constants]::ColorError)
             $context.Console.WriteLineColored("  $($createRes.Output)", [Constants]::ColorError)
             Start-Sleep -Seconds 3
             return
        }
        $context.Console.WriteLineColored(" DONE", [Constants]::ColorSuccess)
        
        # Merge Source
        $context.Console.WriteColored("  Merging '$sourceBranch'...", [Constants]::ColorHint)
        $mergeRes = $gitService.Merge($repo.FullPath, $sourceBranch)
        if (-not $mergeRes.Success) {
             $context.Console.WriteLineColored(" FAILED", [Constants]::ColorError)
             $context.Console.WriteLineColored("  $($mergeRes.Output)", [Constants]::ColorError)
             if ($mergeRes.Output -match "CONFLICT") {
                 $context.Console.WriteLineColored("  [!] Please resolve conflicts in IDE and finish manually.", [Constants]::ColorWarning)
             }
             Start-Sleep -Seconds 4
             return
        }
        $context.Console.WriteLineColored(" DONE", [Constants]::ColorSuccess)

        # Push
        $context.Console.WriteColored("  Pushing to origin...", [Constants]::ColorHint)
        $pushRes = $gitService.Push($repo.FullPath, $newBranchName)
        if (-not $pushRes.Success) {
             $context.Console.WriteLineColored(" FAILED", [Constants]::ColorError)
             $context.Console.WriteLineColored("  $($pushRes.Output)", [Constants]::ColorError)
             Start-Sleep -Seconds 3
             return
        }
        $context.Console.WriteLineColored(" DONE", [Constants]::ColorSuccess)
        
        # PR URL
        $repoUrl = $gitService.GetRepoUrl($repo.FullPath)
        if ($repoUrl) {
            # GitHub: /compare/target...new?expand=1
            # But target is often 'origin/main', we need 'main'
            # Simplify: Just open /compare/new_branch
            # GitHub usually redirects to a PR creation page
            $prUrl = "{0}/compare/{1}?expand=1" -f $repoUrl, $newBranchName
            
            $context.Console.NewLine()
            $openPr = $context.OptionSelector.SelectYesNo("Open Pull Request in Browser?")
            if ($openPr) {
                Start-Process $prUrl
            }
        }
    }
}
