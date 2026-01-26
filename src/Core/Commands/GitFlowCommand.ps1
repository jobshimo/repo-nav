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
            while ($true) {
                $branches = $gitService.GetBranches($repo.FullPath)
                if ($branches.Count -eq 0) {
                    $context.Console.WriteError("No branches found") 
                    Start-Sleep -Milliseconds 1000
                    return
                }
                
                # Select Base Branch OR Switch Branch
                $selectBaseTitle = $this.GetLoc($context, "Flow.SelectBase", "SELECT BRANCH")
                $selectBasePrompt = $this.GetLoc($context, "Flow.SelectBasePrompt", "From Branch")
                
                # Header Options
                $headerOptions = @("flow1", "flow2", "flow3")
                
                # The selector now returns a hashtable: @{ Type=...; Value=... }
                $selection = $selector.ShowSelection($selectBaseTitle, $branches, $selectBasePrompt, $headerOptions)
                
                if ($null -eq $selection) { break } # Cancelled (Esc)
                
                if ($selection.Type -eq "Header") {
                    # Top option selected: flow1, flow2, flow3
                    # Currently no functionality, just loop back.
                    continue
                }
                
                if ($selection.Type -eq "Item") {
                    $targetBranch = $selection.Value
                    
                    $currentBranch = $gitService.GetCurrentBranch($repo.FullPath)
                    if ($targetBranch -eq $currentBranch) {
                        # Already on this branch
                        continue
                    }
                    
                    # Check for uncommitted changes
                    if ($gitService.HasUncommittedChanges($repo.FullPath)) {
                         $context.Console.NewLine()
                         $context.Console.WriteLineColored("  Cannot checkout '$targetBranch': You have uncommitted changes.", [Constants]::ColorError)
                         $context.Console.WriteLineColored("  Please commit or stash your changes first.", [Constants]::ColorHint)
                         Start-Sleep -Seconds 2
                         continue
                    }
                    
                    # Attempt checkout
                    $context.Console.NewLine()
                    $context.Console.WriteColored("  Checking out '$targetBranch'...", [Constants]::ColorHint)
                    
                    if ($gitService.Checkout($repo.FullPath, $targetBranch)) {
                         $context.Console.WriteLineColored(" DONE", [Constants]::ColorSuccess)
                         Start-Sleep -Milliseconds 500
                         
                         # Loop continues, showing the menu again (with likely updated current branch if we visualized it)
                    } else {
                         $context.Console.WriteLineColored(" FAILED", [Constants]::ColorError)
                         Start-Sleep -Seconds 2
                    }
                    
                    continue
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
