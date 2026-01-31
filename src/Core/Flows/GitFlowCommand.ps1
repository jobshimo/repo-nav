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
        
        
        $needsRedraw = $false

        try {
            if (-not $gitService.IsGitRepository($repo.FullPath)) {
                 $context.Console.WriteLineColored($this.GetLoc($context, "UI.NoGit", "Not a git repository"), [Constants]::ColorError)
                 # No sleep to allow immediate navigation
                 return
            }
            
            # We are entering a complex UI flow, so we will need to redraw when finished
            $needsRedraw = $true

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
                $errNoBranches = $this.GetLoc($context, "Flow.Error.NoBranches", "No branches found")
                if ($branches.Count -eq 0) {
                    $context.Console.WriteLineColored($errNoBranches, [Constants]::ColorError) 
                    Start-Sleep -Milliseconds 1000
                    return
                }
                
                # Select Base Branch OR Switch Branch
                $selectBaseTitle = $this.GetLoc($context, "Flow.SelectBase", "SELECT BRANCH")
                $selectBasePrompt = $this.GetLoc($context, "Flow.SelectBasePrompt", "From Branch")
                
                # Header Options
                $optIntegrate = $this.GetLoc($context, "Flow.Option.Integrate", "Integrate")
                $optFlow2 = $this.GetLoc($context, "Flow.Option.Flow2", "Flow 2")
                $optFlow3 = $this.GetLoc($context, "Flow.Option.Flow3", "Flow 3")
                $flowOptions = @($optIntegrate, $optFlow2, $optFlow3)
                
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
                    
                    $isCurrent = ($selectedBranch -eq $currentBranch)
                    
                    # --- BRANCH ACTION MENU ---
                    # 1. Get Tracking Status
                    $tracking = $gitService.GetBranchTrackingStatus($repo.FullPath, $selectedBranch)
                    
                    # 2. Build Action Menu
                    $actionOptions = [System.Collections.Generic.List[string]]::new()
                    
                    $optCheckout = $this.GetLoc($context, "Flow.Action.Checkout", "Checkout")
                    # Can only checkout if NOT current
                    if (-not $isCurrent) {
                        $actionOptions.Add($optCheckout)
                    }
                    
                    $optPull = $this.GetLoc($context, "Flow.Action.Pull", "Pull")
                    if ($tracking.Behind -gt 0) {
                        $actionOptions.Add($optPull)
                    }
                    
                    $optDeleteLocal = $this.GetLoc($context, "Flow.Action.DeleteLocal", "Delete Local Branch")
                    $optDeleteRemote = $this.GetLoc($context, "Flow.Action.DeleteRemote", "Delete Remote Branch")
                    
                    # Can only delete if NOT current
                    if (-not $isCurrent) {
                        $actionOptions.Add($optDeleteLocal)
                    }
                    
                    # Remote Delete option - check if remote exists
                    $remoteExists = $gitService.RemoteBranchExists($repo.FullPath, $selectedBranch)
                    if ($remoteExists) {
                         $actionOptions.Add($optDeleteRemote)
                    }
                    
                    if ($actionOptions.Count -eq 0) {
                        $statusMessage = $this.GetLoc($context, "Flow.Status.CurrentUpToDate", "Current branch '{0}' is up to date.") -f $selectedBranch
                        $statusColor = [Constants]::ColorInfo
                        continue
                    }
                    
                    # Show Action Menu (using same selector but simple list)
                    $actionTitle = $this.GetLoc($context, "Flow.ActionTitle", "ACTION: {0}") -f $selectedBranch
                    $actionSelectorOptions = @{
                        Prompt        = $this.GetLoc($context, "Flow.ActionPrompt", "Select Action")
                        InitialFocus  = [Constants]::FocusInput
                    }
                    
                    $actionSelection = $selector.ShowSelection($actionTitle, $actionOptions, $actionSelectorOptions)
                    
                    if ($null -eq $actionSelection) { continue } # Cancelled back to branch list
                    
                    $action = $actionSelection.Value
                    
                    # --- EXECUTE ACTION ---
                    if ($action -eq $optCheckout) {
                        # CHECKOUT LOGIC
                        $hasChanges = $gitService.HasUncommittedChanges($repo.FullPath)
                        if ($hasChanges) {
                            $fmtErr = $this.GetLoc($context, "Flow.Error.CheckoutUncommitted", "Error: Cannot checkout '{0}'. You have uncommitted changes.")
                            $statusMessage = $fmtErr -f $selectedBranch
                            $statusColor = [Constants]::ColorError
                        } else {
                            $result = $gitService.Checkout($repo.FullPath, $selectedBranch)
                            if ($result.Success) {
                                $fmtSuccess = $this.GetLoc($context, "Flow.Status.CheckoutSuccess", "Checked out '{0}' successfully.")
                                $statusMessage = $fmtSuccess -f $selectedBranch
                                $statusColor = [Constants]::ColorSuccess
                            } else {
                                $err = if ($result.Message) { $result.Message } else { "Unknown error" }
                                $fmtErr = $this.GetLoc($context, "Flow.Error.CheckoutFailed", "Error checking out: {0}")
                                $statusMessage = $fmtErr -f $err
                                $statusColor = [Constants]::ColorError
                            }
                        }
                    }
                    elseif ($action -eq $optPull) {
                        # PULL LOGIC
                        # 1. Checkout
                        $checkoutResult = $gitService.Checkout($repo.FullPath, $selectedBranch)
                        if (-not $checkoutResult.Success) {
                            $statusMessage = "Checkout failed: " + $checkoutResult.Message
                            $statusColor = [Constants]::ColorError
                        } else {
                            # 2. Pull
                            $context.Console.WriteLineColored("Pulling updates...", [Constants]::ColorInfo)
                            $pullResult = $gitService.Pull($repo.FullPath)
                            
                            if ($pullResult.Success) {
                                $statusMessage = "Branch updated successfully."
                                $statusColor = [Constants]::ColorSuccess
                            } else {
                                $statusMessage = "Pull failed: " + $pullResult.Message
                                $statusColor = [Constants]::ColorError
                            }
                        }
                    }
                    elseif ($action -eq $optDeleteLocal) {
                        # DELETE LOCAL LOGIC
                        $prompt = $this.GetLoc($context, "Flow.Prompt.DeleteLocal", "Delete local branch '{0}'? (FORCE CAREFUL)") -f $selectedBranch
                        $confirmLocal = $selector.ShowSelection("DELETE LOCAL?", @("Yes", "No"), @{ Prompt = $prompt })
                        
                        if ($confirmLocal.Value -eq "Yes") {
                            $delResult = $gitService.DeleteLocalBranch($repo.FullPath, $selectedBranch, $true) # Force = true
                            
                            if ($delResult.Success) {
                                $statusMessage = $this.GetLoc($context, "Flow.Status.LocalDeleted", "Local branch '{0}' deleted.") -f $selectedBranch
                                $statusColor = [Constants]::ColorSuccess
                            } else {
                                $fmtErr = $this.GetLoc($context, "Flow.Status.DeleteFailed", "Failed to delete: {0}")
                                $statusMessage = $fmtErr -f $delResult.Message
                                $statusColor = [Constants]::ColorError
                            }
                        }
                    }
                    elseif ($action -eq $optDeleteRemote) {
                        # DELETE REMOTE LOGIC
                        $prompt = $this.GetLoc($context, "Flow.Prompt.DeleteRemote", "Delete remote branch 'origin/{0}'? (IRREVERSIBLE)") -f $selectedBranch
                        $confirmRemote = $selector.ShowSelection("DELETE REMOTE?", @("Yes", "No"), @{ Prompt = $prompt })
                        
                        if ($confirmRemote.Value -eq "Yes") {
                            $context.Console.WriteLineColored("Deleting remote branch...", [Constants]::ColorWarning)
                            $remResult = $gitService.DeleteRemoteBranch($repo.FullPath, $selectedBranch)
                            
                            if ($remResult.Success) {
                                $statusMessage = $this.GetLoc($context, "Flow.Status.RemoteDeleted", "Remote branch 'origin/{0}' deleted.") -f $selectedBranch
                                $statusColor = [Constants]::ColorSuccess
                            } else {
                                $fmtErr = $this.GetLoc($context, "Flow.Status.DeleteFailed", "Failed to delete: {0}")
                                $statusMessage = $fmtErr -f $remResult.Message
                                $statusColor = [Constants]::ColorWarning
                            }
                        }
                    }
                }
                elseif ($selection.Type -eq "Header") {
                    $flow = $selection.Value
                    
                    if ($flow -eq $optIntegrate) {
                        $integrationResult = $this.InvokeIntegrationFlow($context, $repo, $gitService, $selector)
                        # After flow, show result
                        $statusMessage = $integrationResult
                        
                        $cancelledMsg = $this.GetLoc($context, "Flow.Status.Cancelled", "Integration Cancelled")
                        
                        if ($statusMessage -like "Error*") {
                             $statusColor = [Constants]::ColorError
                        } elseif ($statusMessage -eq $cancelledMsg) {
                             $statusColor = [Constants]::ColorWarning
                        } else {
                             $statusColor = [Constants]::ColorSuccess
                        }
                    } elseif ($flow -eq $optFlow2) {
                        $quickResult = $this.InvokeQuickChangeFlow($context, $repo)
                        $statusMessage = $quickResult
                        $statusColor = [Constants]::ColorHint
                    } else {
                        $fmtNotImpl = $this.GetLoc($context, "Flow.Status.NotImplemented", "Selected Flow: {0} (Not implemented)")
                        $statusMessage = $fmtNotImpl -f $flow
                        $statusColor = [Constants]::ColorWarning
                    }
                }
            }
        }
        catch {
             $context.Console.WriteLineColored("Unexpected error in Flow: $_", [Constants]::ColorError)
             $context.Console.ReadKey()
        }
        finally {
             # Resume navigation
             $state.Resume()
             
             # Only full redraw if we actually entered the UI flow
             if ($needsRedraw) {
                $state.MarkForFullRedraw()
             }
        }
    }

    hidden [string] InvokeIntegrationFlow($context, $repo, $gitService, $selector) {
        $controller = [IntegrationFlowController]::new($context, $repo, $gitService, $selector)
        return $controller.Start()
    }

    hidden [string] InvokeQuickChangeFlow($context, $repo) {
        $controller = [QuickChangeFlowController]::new($context, $repo)
        return $controller.Start()
    }
}
