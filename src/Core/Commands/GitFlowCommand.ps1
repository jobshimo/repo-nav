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
                $flowOptions = @("flow1", "flow2", "flow3")
                
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
                    # Future flow logic...
                    # For now just update status with cleaner message
                    $statusMessage = "Selected Flow: $($selection.Value) (Not implemented)"
                    $statusColor = [Constants]::ColorWarning
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
