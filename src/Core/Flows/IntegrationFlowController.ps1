class IntegrationFlowController : FlowControllerBase {
    [FilteredListSelector] $Selector
    [IntegrationFlowDashboard] $Dashboard
    [IntegrationFlowModel] $Model

    # Cache for remote branches
    [array] $RemoteBranches = $null

    IntegrationFlowController([CommandContext]$context, [object]$repo, [GitService]$gitService, [FilteredListSelector]$selector) : base($context, $repo) {
        $this.Selector = $selector
        
        # Instantiate View and Model
        $this.Model = [IntegrationFlowModel]::new()
        $this.Dashboard = [IntegrationFlowDashboard]::new($context.Console, $context.Renderer, $context.LocalizationService)
    }

    [string] Start() {
        # 0. Check for uncommitted changes BEFORE doing anything
        $hasChanges = $this.GitService.HasUncommittedChanges($this.Repo.FullPath)
        if ($hasChanges) {
            $this.Context.Console.ClearScreen()
            $warningTitle = $this.Context.LocalizationService.Get("Flow.Error.UncommittedTitle", "UNCOMMITTED CHANGES DETECTED")
            $this.Context.Renderer.RenderHeader($warningTitle)
            $this.Context.Console.NewLine()
            
            $currentBranch = $this.GitService.GetCurrentBranch($this.Repo.FullPath)
            $fmtBranch = $this.Context.LocalizationService.Get("Flow.Quick.Current", "Current Branch: {0}")
            $this.Context.Console.WriteLineColored("  $($fmtBranch -f $currentBranch)", [Constants]::ColorWarning)
            $this.Context.Console.NewLine()
            
            $msgWarning = $this.Context.LocalizationService.Get("Flow.Error.UncommittedWarning", "You have uncommitted changes in your working directory.")
            $this.Context.Console.WriteLineColored("  [!] $msgWarning", [Constants]::ColorError)
            $this.Context.Console.NewLine()
            
            $msgHint = $this.Context.LocalizationService.Get("Flow.Error.UncommittedHint", "Please commit or stash your changes before starting the integration flow.")
            $this.Context.Console.WriteLineColored("  $msgHint", [Constants]::ColorHint)
            $this.Context.Console.NewLine()
            
            $msgPress = $this.Context.LocalizationService.Get("Flow.Status.PressAnyKey", "Press any key to return to menu...")
            $this.Context.Console.WriteLineColored("  $msgPress", [Constants]::ColorMenuText)
            $this.Context.Console.ReadKey()
            
            return $this.Context.LocalizationService.Get("Flow.Status.AbortedUncommitted", "Aborted: Uncommitted changes detected")
        }
        
        # 1. Init (Fetch)
        $this.Initialize()
        
        # 2. Init State
        # $this.Model.SourceBranch = $this.GitService.GetCurrentBranch($this.Repo.FullPath)
        # $this.Model.SourceBranchValid = $true
        
        # 3. Main Loop
        $selectedIndex = 0
        $this.Dashboard.RenderFull($this.Model, $selectedIndex)
        
        while ($true) {
            $canExecute = $this.Model.IsReadyToExecute()
            $maxIndex = if ($canExecute) { 4 } else { 3 }
            
            # Input Handling
            $key = $this.Context.Console.ReadKey()
            $keyCode = $key.VirtualKeyCode
            
            # Navigation
            if ($keyCode -eq [Constants]::KEY_UP_ARROW) {
                if ($selectedIndex -gt 0) { 
                    $selectedIndex--
                    $this.Dashboard.UpdateSelection($this.Model, $selectedIndex)
                } else { 
                    $selectedIndex = $maxIndex 
                    $this.Dashboard.UpdateSelection($this.Model, $selectedIndex)
                }
                continue
            }
            if ($keyCode -eq [Constants]::KEY_DOWN_ARROW) {
                if ($selectedIndex -lt $maxIndex) { 
                    $selectedIndex++ 
                    $this.Dashboard.UpdateSelection($this.Model, $selectedIndex)
                } else { 
                    $selectedIndex = 0 
                    $this.Dashboard.UpdateSelection($this.Model, $selectedIndex)
                }
                continue
            }
            
            # Cancel/Exit
            if ($keyCode -eq [Constants]::KEY_Q -or $keyCode -eq [Constants]::KEY_ESC) {
                return $this.Context.LocalizationService.Get("Flow.Status.Cancelled", "Integration Cancelled")
            }
            
            # Selection/Action
            if ($keyCode -eq [Constants]::KEY_ENTER) {
                $action = ""
                # Map index to action
                if ($selectedIndex -eq 0) { $action = "SetTarget" }
                elseif ($selectedIndex -eq 1) { $action = "SetName" }
                elseif ($selectedIndex -eq 2) { $action = "SetSource" }
                elseif ($canExecute -and $selectedIndex -eq 3) { $action = "Execute" }
                else { return $this.Context.LocalizationService.Get("Flow.Status.Cancelled", "Integration Cancelled") } # Exit
                
                $result = $this.HandleAction($action)
                
                if ($action -eq "Execute" -and $result) {
                     # If execute returned a string (message), we are done
                     return $result
                }
                
                # If we just updated a value, re-render that line + actions
                if ($action -ne "Execute") {
                    $this.Dashboard.UpdateValue($this.Model, $selectedIndex)
                    # Re-render full if needed? No, UpdateValue handles line + actions
                    # Ensure cursor is hidden again
                    $this.Context.Console.HideCursor()
                }
            }
        }
        return $this.Context.LocalizationService.Get("Error.Unreachable", "Error: Unreachable Code")
    }
    
    hidden [void] Initialize() {
        $this.Context.Console.ClearScreen()
        $title = $this.Context.LocalizationService.Get("Flow.Init.Title", "INTEGRATION FLOW: INITIALIZING")
        $this.Context.Renderer.RenderHeader($title)
        $this.Context.Console.NewLine()
        
        $msgFetch = $this.Context.LocalizationService.Get("Flow.Init.Fetching", "Fetching remotes...")
        $this.Context.Console.WriteColored("  $msgFetch", [Constants]::ColorMenuText)
        
        $fetchRes = $this.GitService.Fetch($this.Repo.FullPath)
        if ($fetchRes.Success) {
            $this.Context.Console.WriteLineColored($this.Context.LocalizationService.Get("Status.Done", " DONE"), [Constants]::ColorSuccess)
        } else {
            $msgFail = $this.Context.LocalizationService.Get("Flow.Warning.FetchFailed", "WARNING: Fetch failed")
            $this.Context.Console.WriteLineColored(" $msgFail", [Constants]::ColorWarning)
        }
        Start-Sleep -Milliseconds 300
    }

    hidden [object] HandleAction([string]$action) {
        switch ($action) {
            "SetTarget" {
                if ($null -eq $this.RemoteBranches) {
                    $msgLoad = $this.Context.LocalizationService.Get("Flow.Status.LoadingRemotes", "Loading remote branches...")
                    # We might need to show this somewhere without destroying layout, 
                    # but for now let's hope it's fast or we just block.
                    # Since we are using "Partial Updates", we don't have a specific "Status Line" in dashboard unless we add one.
                    # Let's just block-load.
                    $this.RemoteBranches = $this.GitService.GetRemoteBranches($this.Repo.FullPath)
                }
                $title = $this.Context.LocalizationService.Get("Flow.Action.SetTarget", "Select TARGET Branch")
                $prompt = $this.Context.LocalizationService.Get("Flow.Prompt.RemoteBranch", "Select Remote Branch")
                
                # Show selector (covers screen)
                $sel = $this.Selector.ShowSelection($title, $this.RemoteBranches, @{ Prompt=$prompt; InitialFocus=[Constants]::FocusInput })
                
                # Redraw Dashboard after selector closes
                $this.Dashboard.RenderFull($this.Model, 0)
                
                if ($null -ne $sel -and $sel.Type -eq "Item") {
                    $this.Model.TargetBranch = "$($sel.Value)".Trim()
                    $this.Model.TargetBranchValid = $true
                }
            }
            "SetName" {
                $this.Context.Console.NewLine()
                $prompt = $this.Context.LocalizationService.Get("Flow.Prompt.EnterName", "Enter New Branch Name: ")
                # Clear line for input to avoid artifacts
                $this.Context.Console.ClearCurrentLine()
                
                $this.Context.Console.WriteColored("  $prompt", [ConsoleColor]::Yellow)
                
                $this.Context.Console.ShowCursor()
                $inputName = Read-Host
                $this.Context.Console.HideCursor()
                
                # We broke layout with Read-Host, so Refresh
                $this.Dashboard.RenderFull($this.Model, 1) # Keep index 1

                if (-not [string]::IsNullOrWhiteSpace($inputName)) {
                    $this.Model.NewBranchName = $inputName.Trim()
                    $this.Model.NewBranchNameValid = $true
                }
            }
            "SetSource" {
                $localBranches = $this.GitService.GetBranches($this.Repo.FullPath)
                $title = $this.Context.LocalizationService.Get("Flow.Action.SetSource", "Select SOURCE Branch")
                $prompt = $this.Context.LocalizationService.Get("Flow.Prompt.LocalBranch", "Select Local Branch")
                
                $sel = $this.Selector.ShowSelection($title, $localBranches, @{ Prompt=$prompt; CurrentItem=$this.Model.SourceBranch; InitialFocus=[Constants]::FocusInput })
                
                # Redraw
                $this.Dashboard.RenderFull($this.Model, 2)

                if ($null -ne $sel -and $sel.Type -eq "Item") {
                    $this.Model.SourceBranch = "$($sel.Value)".Trim()
                    $this.Model.SourceBranchValid = $true
                }
            }
            "Execute" {
                return $this.ExecuteIntegration()
            }
        }
        return $null
    }

    hidden [string] ExecuteIntegration() {
         $newBranchName = $this.Model.NewBranchName
         $targetBranch = $this.Model.TargetBranch
         $sourceBranch = $this.Model.SourceBranch
         
         $this.Context.Console.ClearScreen()
         $title = $this.Context.LocalizationService.Get("Flow.Dashboard.Execute", "EXECUTING INTEGRATION")
         $this.Context.Renderer.RenderHeader($title)
         $this.Context.Console.NewLine()
         
         # 1. Create Branch
         $fmtCreate = $this.Context.LocalizationService.Get("Flow.Op.Creating", "Creating '{0}' from '{1}'...")
         $msgCreate = [string]::Format($fmtCreate, $newBranchName, $targetBranch)
         $this.Context.Console.WriteColored("  $msgCreate", [Constants]::ColorHint)
         
         $createRes = $this.GitService.CreateBranch($this.Repo.FullPath, $newBranchName, $targetBranch)
         if (-not $createRes.Success) {
              $this.Context.Console.WriteLineColored($this.Context.LocalizationService.Get("Status.Failed", " FAILED"), [Constants]::ColorError)
              $this.Context.Console.WriteLineColored("  $($createRes.Message)", [Constants]::ColorError)
              $fmtErr = $this.Context.LocalizationService.Get("Flow.Error.CreateFailed", "Failed to create branch '{0}': {1}")
              
              # Pause for user to see error
              $this.Context.Console.WriteLineColored("  Press any key to continue...", [Constants]::ColorHint)
              $this.Context.Console.ReadKey()
              
              return "Error: " + [string]::Format($fmtErr, $newBranchName, $createRes.Message)
         }
         $this.Context.Console.WriteLineColored($this.Context.LocalizationService.Get("Status.Done", " DONE"), [Constants]::ColorSuccess)
         
         # 2. Merge Source
         $fmtMerge = $this.Context.LocalizationService.Get("Flow.Op.Merging", "Merging '{0}'...")
         $msgMerge = [string]::Format($fmtMerge, $sourceBranch)
         $this.Context.Console.WriteColored("  $msgMerge", [Constants]::ColorHint)
         
         $mergeRes = $this.GitService.Merge($this.Repo.FullPath, $sourceBranch)
         if (-not $mergeRes.Success) {
             $this.Context.Console.WriteLineColored($this.Context.LocalizationService.Get("Status.Failed", " FAILED"), [Constants]::ColorError)
             $this.Context.Console.WriteLineColored("  $($mergeRes.Message)", [Constants]::ColorError)
             if ($mergeRes.Message -match "CONFLICT") {
                 $msgConflict = $this.Context.LocalizationService.Get("Flow.Error.Conflict", "Please resolve conflicts in IDE.")
                 $this.Context.Console.WriteLineColored("  [!] $msgConflict", [Constants]::ColorWarning)
             }
             $fmtErr = $this.Context.LocalizationService.Get("Flow.Error.MergeFailed", "Merge failed: {0}")
             
             # Pause for user to see error
             $this.Context.Console.WriteLineColored("  Press any key to continue...", [Constants]::ColorHint)
             $this.Context.Console.ReadKey()
             
             return "Error: " + [string]::Format($fmtErr, $mergeRes.Message)
         }
         $this.Context.Console.WriteLineColored($this.Context.LocalizationService.Get("Status.Done", " DONE"), [Constants]::ColorSuccess)

         # 3. Version Check (Logic reused)
         $this.HandleVersionBump($newBranchName)

         # 4. Push
         $msgPush = $this.Context.LocalizationService.Get("Flow.Status.Pushing", "Pushing to origin...")
         $this.Context.Console.WriteColored("  $msgPush", [Constants]::ColorHint)
         $pushRes = $this.GitService.Push($this.Repo.FullPath, $newBranchName)
         if (-not $pushRes.Success) {
             $this.Context.Console.WriteLineColored($this.Context.LocalizationService.Get("Status.Failed", " FAILED"), [Constants]::ColorError)
             $this.Context.Console.WriteLineColored("  $($pushRes.Message)", [Constants]::ColorError)
             $fmtErr = $this.Context.LocalizationService.Get("Flow.Error.PushFailed", "Push failed: {0}")
             
             # Pause for user to see error
             $this.Context.Console.WriteLineColored("  Press any key to continue...", [Constants]::ColorHint)
             $this.Context.Console.ReadKey()
             
             return "Error: " + [string]::Format($fmtErr, $pushRes.Message)
         }
         $this.Context.Console.WriteLineColored($this.Context.LocalizationService.Get("Status.Done", " DONE"), [Constants]::ColorSuccess)
         
         # 5. PR URL
         $this.HandlePullRequest($newBranchName)
         
         return $this.Context.LocalizationService.Get("Flow.Status.Completed", "Integration Flow Completed.")
    }

    hidden [void] HandleVersionBump([string]$newVersionBranch) {
        $npmService = $this.Context.RepoManager.NpmService
        if ($npmService.HasPackageJson($this.Repo.FullPath)) {
             $currentVersion = $npmService.GetVersion($this.Repo.FullPath)
             
             $promptTitle = $this.Context.LocalizationService.Get("Flow.UpdateVersionPrompt", "Do you want to update the version?")
             $fmtV = $this.Context.LocalizationService.Get("Flow.CurrentVersion", "Current Version: {0}")
             $desc = [string]::Format($fmtV, $currentVersion)
             
             $yesText = $this.Context.LocalizationService.Get("Prompt.Yes", "Yes")
             $noText = $this.Context.LocalizationService.Get("Prompt.No", "No")
             $cancelText = $this.Context.LocalizationService.Get("Prompt.Cancel", "Cancel")
             
             $yesNoOptions = @(
                 @{ DisplayText = $yesText; Value = $true },
                 @{ DisplayText = $noText;  Value = $false }
             )
             
             $config = [SelectionOptions]::new()
             $config.Title = $promptTitle
             $config.Options = $yesNoOptions
             $config.CancelText = $cancelText
             $config.ShowCurrentMarker = $false
             $config.Description = $desc
             $updateChoice = $this.Context.OptionSelector.Show($config)
             
             if ($true -eq $updateChoice) {
                 $this.Context.Console.NewLine()
                 $enterPrompt = $this.Context.LocalizationService.Get("Flow.EnterNewVersion", "Enter new version: ")
                 $this.Context.Console.WriteColored("  $enterPrompt", [Constants]::ColorMenuText)
                 $this.Context.Console.ShowCursor()
                 $newVersion = Read-Host
                 $this.Context.Console.HideCursor()
                 
                 if (-not [string]::IsNullOrWhiteSpace($newVersion)) {
                     $msgUpdating = $this.Context.LocalizationService.Get("Flow.UpdatingVersion", "Updating version...")
                     $this.Context.Console.WriteColored("  $msgUpdating", [Constants]::ColorHint)
                     $setRes = $npmService.SetVersion($this.Repo.FullPath, $newVersion)
                     
                     if ($setRes.Success) {
                         $this.Context.Console.WriteLineColored($this.Context.LocalizationService.Get("Status.Done", " DONE"), [Constants]::ColorSuccess)
                         
                         $msgCommitting = $this.Context.LocalizationService.Get("Flow.CommitVersionBump", "Committing version bump...")
                         $this.Context.Console.WriteColored("  $msgCommitting", [Constants]::ColorHint)
                         
                         [void]$this.GitService.Add($this.Repo.FullPath, "package.json")
                         if ($npmService.HasPackageLock($this.Repo.FullPath)) {
                             [void]$this.GitService.Add($this.Repo.FullPath, "package-lock.json")
                         }
                         
                         $commitRes = $this.GitService.Commit($this.Repo.FullPath, "chore: bump version to $newVersion")
                         if ($commitRes.Success) {
                             $this.Context.Console.WriteLineColored($this.Context.LocalizationService.Get("Status.Done", " DONE"), [Constants]::ColorSuccess)
                         } else {
                             $this.Context.Console.WriteLineColored($this.Context.LocalizationService.Get("Status.Failed", " FAILED"), [Constants]::ColorError)
                             $this.Context.Console.WriteLineColored($this.Context.LocalizationService.Get("Flow.Warning.RunningWithoutCommit", "  Running without commit..."), [Constants]::ColorWarning)
                         }
                     } else {
                         $this.Context.Console.WriteLineColored($this.Context.LocalizationService.Get("Status.Failed", " FAILED"), [Constants]::ColorError)
                     }
                 }
             }
        }
    }

    hidden [void] HandlePullRequest([string]$branchName) {
        $msgCheck = $this.Context.LocalizationService.Get("Flow.Status.CheckingPR", "Checking PR capability...")
        $this.Context.Console.WriteColored("  $msgCheck", [Constants]::ColorHint)
        $repoUrl = $this.GitService.GetRepoUrl($this.Repo.FullPath)
        
        if (-not [string]::IsNullOrWhiteSpace($repoUrl)) {
            $this.Context.Console.WriteLineColored($this.Context.LocalizationService.Get("Status.Done", " DONE"), [Constants]::ColorSuccess)
            $prUrl = "{0}/compare/{1}?expand=1" -f $repoUrl, $branchName
            
            $this.Context.Console.NewLine()
            $promptPr = $this.Context.LocalizationService.Get("Flow.OpenPrPrompt", "Open Pull Request on GitHub?")
            $openPr = $this.Context.OptionSelector.SelectYesNo($promptPr)
            if ($openPr) {
                Start-Process $prUrl
            }
        } else {
            $this.Context.Console.WriteLineColored($this.Context.LocalizationService.Get("Flow.Warning.SkipNoUrl", " SKIP (No URL)"), [Constants]::ColorWarning)
            $this.Context.Console.NewLine()
            $msgNoUrl = $this.Context.LocalizationService.Get("Flow.Error.PrUrlNotFound", "[i] Could not determine Pull Request URL.")
            $this.Context.Console.WriteLineColored("  $msgNoUrl", [Constants]::ColorHint)
        }
    }
}
