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
            
            $branches = $gitService.GetBranches($repo.FullPath)
            if ($branches.Count -eq 0) {
                # "No branches found" - reusing prompt or generic? Adding generic.
                $context.Console.WriteError("No branches found") 
                Start-Sleep -Milliseconds 1000
                return
            }
            
            # Select Base Branch
            $selectBaseTitle = $this.GetLoc($context, "Flow.SelectBase", "SELECT BASE BRANCH")
            $selectBasePrompt = $this.GetLoc($context, "Flow.SelectBasePrompt", "From Branch")
            
            $baseBranch = $selector.ShowSelection($selectBaseTitle, $branches, $selectBasePrompt)
            if ([string]::IsNullOrEmpty($baseBranch)) { return } # Cancelled
            
            # 2. Input New Branch Name
            $createTitle = $this.GetLoc($context, "Flow.CreateTitle", "CREATE NEW BRANCH")
            $enterNamePrompt = $this.GetLoc($context, "Flow.EnterName", "Enter new branch name: ")
            
            $context.Console.ClearScreen()
            $context.Renderer.RenderHeader($createTitle)
            $context.Console.NewLine()
            $context.Console.WriteColored("  $($selectBasePrompt): ", [Constants]::ColorLabel)
            $context.Console.WriteLineColored($baseBranch, [Constants]::ColorValue)
            $context.Console.NewLine()
            $context.Console.WriteColored("  $enterNamePrompt", [Constants]::ColorLabel)
            
            # Simple input reading
            $context.Console.ShowCursor()
            $newBranchName = Read-Host
            $context.Console.HideCursor()
            
            if ([string]::IsNullOrWhiteSpace($newBranchName)) { return }
            
            # Create and Checkout
            $context.Console.NewLine()
            $creatingMsg = $this.GetLoc($context, "Flow.Creating", "Creating branch '{0}'...") -f $newBranchName
            $context.Console.WriteColored("  $creatingMsg", [Constants]::ColorHint)
            
            if ($gitService.CreateBranch($repo.FullPath, $newBranchName, $baseBranch)) {
                $context.Console.WriteLineColored(" DONE", [Constants]::ColorSuccess)
            } else {
                 $context.Console.WriteLineColored(" FAILED", [Constants]::ColorError)
                 Start-Sleep -Seconds 2
                 return
            }
            
            Start-Sleep -Milliseconds 500
            
            # 3. Select Branch to Merge
            $mergePrompt = $this.GetLoc($context, "Flow.MergePrompt", "Merge another branch into '{0}'?") -f $newBranchName
            
            if ($context.OptionSelector.SelectYesNo($mergePrompt, $context.LocalizationService)) {
                 $selectMergeTitle = $this.GetLoc($context, "Flow.SelectMergeTitle", "SELECT BRANCH TO MERGE")
                 $selectMergePrompt = $this.GetLoc($context, "Flow.SelectMergePrompt", "Merge Branch")
            
                 $branchToMerge = $selector.ShowSelection($selectMergeTitle, $branches, $selectMergePrompt)
                 
                 if (-not [string]::IsNullOrEmpty($branchToMerge)) {
                    $mergeTitle = $this.GetLoc($context, "Flow.MergeTitle", "MERGING")
                    $mergingMsg = $this.GetLoc($context, "Flow.Merging", "Merging '{0}' into '{1}'...") -f $branchToMerge, $newBranchName
                 
                    $context.Console.ClearScreen()
                    $context.Renderer.RenderHeader($mergeTitle)
                    $context.Console.NewLine()
                    $context.Console.WriteColored("  $mergingMsg", [Constants]::ColorHint)
                    
                    try {
                        $success = $gitService.Merge($repo.FullPath, $branchToMerge)
                        if ($success) {
                             $context.Console.WriteLineColored(" DONE", [Constants]::ColorSuccess)
                        }
                    }
                    catch {
                        $conflictMsg = $this.GetLoc($context, "Flow.Error.Conflict", "Please resolve conflicts in your IDE.")
                        $continueMsg = $this.GetLoc($context, "Prompt.NavigationHint", "Press any key to continue...")
                        
                        $context.Console.NewLine()
                        $context.Console.WriteLineColored("  " + $_.Exception.Message, [Constants]::ColorError)
                        if ($_.Exception.Message -match "CONFLICT") {
                            $context.Console.WriteLineColored("  $conflictMsg", [Constants]::ColorWarning)
                        }
                        $context.Console.WriteLineColored("  $continueMsg", [Constants]::ColorHint)
                        $context.Console.ReadKey()
                    }
                 }
            }
            
            # 4. Open PR
            $oprenPrPrompt = $this.GetLoc($context, "Flow.OpenPrPrompt", "Open Pull Request on GitHub?")
            
            if ($context.OptionSelector.SelectYesNo($oprenPrPrompt, $context.LocalizationService)) {
                $remoteUrl = $gitService.GetRemoteUrl($repo.FullPath)
                $repoName = $gitService.GetRepoNameFromUrl($remoteUrl)
                
                $owner = ""
                $githubRepo = ""
                
                if ($remoteUrl -match 'github\.com[:/]([^/]+)/([^/\.]+)') {
                    $owner = $matches[1]
                    $githubRepo = $matches[2]
                    
                    $prUrl = "https://github.com/$owner/$githubRepo/compare/$baseBranch...$newBranchName"
                    
                    $openPrTitle = $this.GetLoc($context, "Flow.OpenPrTitle", "OPENING PR")
                    $openingMsg = $this.GetLoc($context, "Flow.Opening", "Opening: {0}") -f $prUrl
                    
                    $context.Console.ClearScreen()
                    $context.Renderer.RenderHeader($openPrTitle)
                    $context.Console.NewLine()
                    $context.Console.WriteLineColored("  $openingMsg", [Constants]::ColorLink)
                    
                    Start-Process $prUrl
                    Start-Sleep -Seconds 2
                } else {
                    $context.Console.WriteError("Could not parse GitHub URL from remote: $remoteUrl")
                    Start-Sleep -Seconds 2
                }
            }
        }
        finally {
             # Resume navigation and force redraw
             $state.Resume()
             $state.MarkForFullRedraw()
        }
    }
}
