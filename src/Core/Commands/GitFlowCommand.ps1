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
    
    [string] GetDescription() {
        return "B: Git Flow (Branch & PR)"
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
        
        if (-not $gitService.IsGitRepository($repo.FullPath)) {
             $context.Console.WriteError("Not a git repository")
             Start-Sleep -Milliseconds 1000
             return
        }
        
        # 1. Select Base Branch
        # We need to instantiate specific UI components here or injected into context
        # For now, we'll create them on the fly or we should probably register FilteredListSelector in context
        # But to avoid touching Context definition too much right now, I'll instantiate it here.
        
        $selector = [FilteredListSelector]::new($context.Console, $context.Renderer)
        
        $branches = $gitService.GetBranches($repo.FullPath)
        if ($branches.Count -eq 0) {
            $context.Console.WriteError("No branches found")
            Start-Sleep -Milliseconds 1000
            return
        }
        
        # Select Base Branch
        $baseBranch = $selector.ShowSelection("SELECT BASE BRANCH", $branches, "From Branch")
        if ([string]::IsNullOrEmpty($baseBranch)) { return } # Cancelled
        
        # 2. Input New Branch Name
        $context.Console.ClearScreen()
        $context.Renderer.RenderHeader("CREATE NEW BRANCH")
        $context.Console.NewLine()
        $context.Console.WriteColored("  Base Branch: ", [Constants]::ColorLabel)
        $context.Console.WriteLineColored($baseBranch, [Constants]::ColorValue)
        $context.Console.NewLine()
        $context.Console.WriteColored("  Enter new branch name: ", [Constants]::ColorLabel)
        
        # Simple input reading
        $context.Console.ShowCursor()
        $newBranchName = Read-Host
        $context.Console.HideCursor()
        
        if ([string]::IsNullOrWhiteSpace($newBranchName)) { return }
        
        # Create and Checkout
        $context.Console.NewLine()
        $context.Console.WriteColored("  Creating branch '$newBranchName'...", [Constants]::ColorHint)
        
        if ($gitService.CreateBranch($repo.FullPath, $newBranchName, $baseBranch)) {
            $context.Console.WriteLineColored(" DONE", [Constants]::ColorSuccess)
        } else {
             $context.Console.WriteLineColored(" FAILED", [Constants]::ColorError)
             Start-Sleep -Seconds 2
             return
        }
        
        Start-Sleep -Milliseconds 500
        
        # 3. Select Branch to Merge (Optional? User said "mergear la rama que se quiera llevar")
        # Let's ask if they want to merge anything.
        if ($context.OptionSelector.SelectYesNo("Merge another branch into '$newBranchName'?")) {
             $branchToMerge = $selector.ShowSelection("SELECT BRANCH TO MERGE", $branches, "Merge Branch")
             
             if (-not [string]::IsNullOrEmpty($branchToMerge)) {
                $context.Console.ClearScreen()
                $context.Renderer.RenderHeader("MERGING")
                $context.Console.NewLine()
                $context.Console.WriteColored("  Merging '$branchToMerge' into '$newBranchName'...", [Constants]::ColorHint)
                
                try {
                    $success = $gitService.Merge($repo.FullPath, $branchToMerge)
                    if ($success) {
                         $context.Console.WriteLineColored(" DONE", [Constants]::ColorSuccess)
                    }
                }
                catch {
                    $context.Console.NewLine()
                    $context.Console.WriteLineColored("  " + $_.Exception.Message, [Constants]::ColorError)
                    if ($_.Exception.Message -match "CONFLICT") {
                        $context.Console.WriteLineColored("  Please resolve conflicts in your IDE.", [Constants]::ColorWarning)
                    }
                    $context.Console.WriteLineColored("  Press any key to continue...", [Constants]::ColorHint)
                    $context.Console.ReadKey()
                }
             }
        }
        
        # 4. Open PR
        if ($context.OptionSelector.SelectYesNo("Open Pull Request on GitHub?")) {
            # We assume target is baseBranch usually, but let's let them pick or default to baseBranch
            # Simplify: Generate URL for newBranchName vs baseBranch
            
            $remoteUrl = $gitService.GetRemoteUrl($repo.FullPath)
            $repoName = $gitService.GetRepoNameFromUrl($remoteUrl)
            
            # Extract owner/repo from URL
            # Expected: https://github.com/Owner/Repo.git or git@github.com:Owner/Repo.git
            $owner = ""
            $githubRepo = ""
            
            if ($remoteUrl -match 'github\.com[:/]([^/]+)/([^/\.]+)') {
                $owner = $matches[1]
                $githubRepo = $matches[2]
                
                # URL Structure: https://github.com/Owner/Repo/compare/base...head
                # base = baseBranch
                # head = newBranchName
                
                $prUrl = "https://github.com/$owner/$githubRepo/compare/$baseBranch...$newBranchName"
                
                $context.Console.ClearScreen()
                $context.Renderer.RenderHeader("OPENING PR")
                $context.Console.NewLine()
                $context.Console.WriteLineColored("  Opening: $prUrl", [Constants]::ColorLink)
                
                Start-Process $prUrl
                Start-Sleep -Seconds 2
            } else {
                $context.Console.WriteError("Could not parse GitHub URL from remote: $remoteUrl")
                Start-Sleep -Seconds 2
            }
        }
    }
}
