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
                $context.Console.WriteError("No branches found") 
                Start-Sleep -Milliseconds 1000
                return
            }
            
            # Select Base Branch OR Switch Branch
            $selectBaseTitle = $this.GetLoc($context, "Flow.SelectBase", "SELECT BRANCH")
            $selectBasePrompt = $this.GetLoc($context, "Flow.SelectBasePrompt", "From Branch")
            
            # Header Options
            # For now, just one option that does nothing.
            $headerOptions = @("Create new branch from current...")
            
            # The selector now returns a hashtable: @{ Type=...; Value=... }
            $selection = $selector.ShowSelection($selectBaseTitle, $branches, $selectBasePrompt, $headerOptions)
            
            if ($null -eq $selection) { return } # Cancelled
            
            if ($selection.Type -eq "Header") {
                # Top option selected: "Create new branch from current..."
                # Currently: "tienes que añadir un texto que seta seleccionable... pero al presionar enter no hace nada"
                # So we just return/loop.
                # Just return to main loop for now as requested.
                return
            }
            
            if ($selection.Type -eq "Item") {
                $targetBranch = $selection.Value
                
                # Requested: "cuando presionamos enter sobre una rama seleccionada, esa tiene que ser la rama activa en el repo"
                # "y si no se puede cambiar a ella por que en la actual hay cosas sin comitear... se avisa"
                
                $currentBranch = $gitService.GetCurrentBranch($repo.FullPath)
                if ($targetBranch -eq $currentBranch) {
                    # Already on this branch
                    return
                }
                
                # Check for uncommitted changes
                if ($gitService.HasUncommittedChanges($repo.FullPath)) {
                     $context.Console.NewLine()
                     $context.Console.WriteLineColored("  Cannot checkout '$targetBranch': You have uncommitted changes.", [Constants]::ColorError)
                     $context.Console.WriteLineColored("  Please commit or stash your changes first.", [Constants]::ColorHint)
                     Start-Sleep -Seconds 2
                     return
                }
                
                # Attempt checkout
                $context.Console.NewLine()
                $context.Console.WriteColored("  Checking out '$targetBranch'...", [Constants]::ColorHint)
                
                if ($gitService.Checkout($repo.FullPath, $targetBranch)) {
                     $context.Console.WriteLineColored(" DONE", [Constants]::ColorSuccess)
                     Start-Sleep -Milliseconds 500
                     
                     # Force repo status update in the UI
                     # We can't easily trigger a full refresh from here unless we rely on the main loop update
                     # The main loop usually updates on keypress or interval. 
                     # Adding a small delay helps user see success.
                } else {
                     $context.Console.WriteLineColored(" FAILED", [Constants]::ColorError)
                     Start-Sleep -Seconds 2
                }
                
                return
            }
            
            # --- OLD FLOW (Disabled/Replaced by new requirements) ---
            # If we wanted to keep the "Create New Branch" flow, we would put it under the Header option logic.
            # But the user specifically asked for this new behavior.
            
            # Original Flow Code Stored for reference if we need to move it to a specific option later:
            # $baseBranch = $selection.Value
            # ... Prompt for new name ...
            # ... Create Branch ...
            # ... Merge ...
            # ... PR ...
            
        }
        finally {
             # Resume navigation and force redraw
             $state.Resume()
             $state.MarkForFullRedraw()
        }
    }
}
