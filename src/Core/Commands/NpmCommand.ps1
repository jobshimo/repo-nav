# IMPORTANT: INavigationCommand.ps1 must be loaded BEFORE this file

#
# View Layer: Handles UI interactions, messages, and localization for Npm operations
#
class NpmView {
    [ConsoleHelper] $Console
    [UIRenderer] $Renderer
    [OptionSelector] $OptionSelector
    [LocalizationService] $LocalizationService

    NpmView([CommandContext]$context) {
        $this.Console = $context.Console
        $this.Renderer = $context.Renderer
        $this.OptionSelector = $context.OptionSelector
        $this.LocalizationService = $context.LocalizationService
    }

    hidden [string] GetLoc([string]$key, [string]$default) {
        if ($this.LocalizationService) { 
            $val = $this.LocalizationService.Get($key)
            if ($val -eq "[$key]") { return $default }
            return $val
        }
        return $default
    }

    [void] ClearAndRenderHeader([string]$title, [Object]$repository) {
        $this.Console.ClearForWorkflow()
        $locTitle = $this.GetLoc("Msg.Npm.$title", $title.ToUpper())
        $this.Renderer.RenderWorkflowHeader($locTitle, $repository)
    }

    [void] ShowError([string]$messageKey, [string]$defaultMessage, [string]$detail) {
        $msg = $this.GetLoc($messageKey, $defaultMessage)
        Write-Host $msg -ForegroundColor ([Constants]::ColorError)
        if (-not [string]::IsNullOrEmpty($detail)) {
            Write-Host $detail -ForegroundColor ([Constants]::ColorGray)
        }
        Start-Sleep -Seconds 2
    }

    [void] ShowSuccess([string]$messageKey, [string]$defaultMessage) {
        $msg = $this.GetLoc($messageKey, $defaultMessage)
        Write-Host $msg -ForegroundColor ([Constants]::ColorSuccess)
    }

    [void] ShowNpmNotFound() {
        $this.Console.ClearForWorkflow()
        $this.Renderer.RenderError("npm not found")
        Write-Host ""
        Write-Host ($this.GetLoc("Error.Npm.NotFound", "Error: 'npm' command not found.")) -ForegroundColor ([Constants]::ColorError)
        Write-Host ""
        Write-Host ($this.GetLoc("Error.Npm.InstallNode", "Please install Node.js from https://nodejs.org/")) -ForegroundColor ([Constants]::ColorWarning)
        Start-Sleep -Seconds 4
    }

    [void] ShowExecuting([string]$messageKey, [string]$defaultMessage) {
         $msg = $this.GetLoc($messageKey, $defaultMessage)
         Write-Host "$msg..." -ForegroundColor ([Constants]::ColorWarning)
    }

    [bool] ConfirmRemoval([string]$targetName) {
        $prompt = $this.GetLoc("Prompt.Continue", "Continue?")
        $fmt = $this.GetLoc("Msg.Npm.DeleteWarning", "This will delete: {0}")
        $warning = $fmt -f $targetName

        if ($this.OptionSelector) {
            $yes = $this.GetLoc("Prompt.Yes", "Yes")
            $no = $this.GetLoc("Prompt.No", "No")
            $options = @(
                @{ DisplayText = $yes; Value = $true },
                @{ DisplayText = $no; Value = $false }
            )
            # Fixed: Passed explicit $true for clearScreen (7th argument)
            $result = $this.OptionSelector.ShowSelection($prompt, $options, $false, "Cancel", $false, $warning, $true)
            return ($result -eq $true)
        } else {
            Write-Host $warning -ForegroundColor ([Constants]::ColorWarning)
            return $this.Console.ConfirmAction($prompt, $false)
        }
    }

    [bool] ConfirmRemovePackageLock() {
        $prompt = $this.GetLoc("Msg.Npm.RemoveLockPrompt", "Do you also want to remove package-lock.json?")

        if ($this.OptionSelector) {
            $yes = $this.GetLoc("Prompt.Yes", "Yes")
            $no = $this.GetLoc("Prompt.No", "No")
            $options = @(
                @{ DisplayText = $yes; Value = $true },
                @{ DisplayText = $no; Value = $false }
            )
            # Fixed: Passed explicit $true for clearScreen (7th argument)
            $result = $this.OptionSelector.ShowSelection($prompt, $options, $false, "Cancel", $false, $null, $true)
            return ($result -eq $true)
        } else {
            return $this.Console.ConfirmAction($prompt, $false)
        }
    }

    [void] ShowOperationCancelled() {
        Write-Host ($this.GetLoc("Msg.ActionCancelled", "Operation cancelled.")) -ForegroundColor ([Constants]::ColorWarning)
        Start-Sleep -Seconds 1
    }
}

#
# Command Layer: Orchestrates Service and View
#
class NpmCommand : INavigationCommand {
    
    [string] GetDescription() {
        return "Install npm (I) or Remove node_modules (X)"
    }

    [bool] CanExecute([object]$keyPress, [CommandContext]$context) {
        $key = $keyPress.VirtualKeyCode
        return $key -eq [Constants]::KEY_I -or $key -eq [Constants]::KEY_X
    }

    [void] Execute([object]$keyPress, [CommandContext]$context) {
        $state = $context.State
        $repos = $state.GetRepositories()
        $currentIndex = $state.GetCurrentIndex()
        
        if ($repos.Count -eq 0) { return }
        $currentRepo = $repos[$currentIndex]
        $key = $keyPress.VirtualKeyCode
        
        $state.Stop() # Pause navigation loop
        # Ensure cursor hidden/shown as needed by view methods, generally View handles it or OptionSelector
        
        try {
            $view = [NpmView]::new($context)
            $npmService = $context.RepoManager.NpmService

            if ($key -eq [Constants]::KEY_I) {
                $this.InvokeInstall($context, $currentRepo, $view, $npmService)
            }
            elseif ($key -eq [Constants]::KEY_X) {
                $this.InvokeRemove($context, $currentRepo, $view, $npmService)
            }
            
            # Refresh Repository Data logic
            $this.RefreshRepositoryState($context, $currentRepo)
        }
        finally {
            $state.Resume()
        }
    }

    hidden [void] InvokeInstall($context, $repo, $view, $service) {
        # 1. Validation
        if (-not ($service.HasPackageJson($repo.FullPath))) {
            $view.ClearAndRenderHeader("Installing", $repo)
            $view.ShowError("Error.Repo.NoPackageJson", "No package.json found.", $null)
            return
        }

        $npmPath = $service.GetNpmExecutablePath()
        if (-not $npmPath) {
            $view.ShowNpmNotFound()
            return
        }

        # 2. Execution UI
        $view.ClearAndRenderHeader("Installing", $repo)
        
        # 3. Process Execution
        try {
            # Synchronous Execution without background jobs
            $view.ShowExecuting("Msg.Npm.RunningInstall", "Running npm install")
            
            Push-Location $repo.FullPath
            try {
                try { [Console]::CursorVisible = $true } catch {}
                
                # Use Start-Process with cmd /c for standard output streaming
                $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$npmPath`" install" -WorkingDirectory $repo.FullPath -NoNewWindow -Wait -PassThru
            
                $exitCode = $proc.ExitCode
                
                if ($exitCode -eq 0) {
                     Write-Host ""
                     $view.ShowSuccess("Msg.Npm.Success", "Dependencies installed successfully!")
                     Start-Sleep -Seconds 2
                } else {
                     Write-Host ""
                     $view.ShowError("Error.Npm.Failed", "npm install failed with exit code $exitCode", $null)
                }
            }
            finally {
                Pop-Location
                try { [Console]::CursorVisible = $false } catch {}
            }
        }
        catch {
            $view.ShowError("Error.Npm.Exception", "Error running npm: ", $_)
        }
    }

    hidden [void] InvokeRemove($context, $repo, $view, $service) {
        $nodeModulesPath = Join-Path $repo.FullPath "node_modules"
        
        # 1. Validation
        if (-not ($service.HasNodeModules($repo.FullPath))) {
            $view.ClearAndRenderHeader("Removing", $repo)
            $view.ShowError("Error.Repo.NoNodeModules", "No node_modules folder found.", $null)
            return
        }

        # 2. Confirmation (Uses OptionSelector internally)
        $view.ClearAndRenderHeader("Removing", $repo)
        if (-not ($view.ConfirmRemoval("node_modules"))) {
            $view.ShowOperationCancelled()
            return
        }

        # Check for package-lock.json
        $removeLock = $false
        if ($service.HasPackageLock($repo.FullPath)) {
             # Re-render header to keep context (OptionSelector might clear below it)
             $view.ClearAndRenderHeader("Removing", $repo)
             if ($view.ConfirmRemovePackageLock()) {
                 $removeLock = $true
             }
        }

        # 3. Execution (Synchronous - No Animation/Job complications)
        $view.ClearAndRenderHeader("Removing", $repo)
        Write-Host ""
        $view.ShowExecuting("Msg.Npm.Removing", "Removing node_modules")
        
        # Synchronous removal
        $result = $service.RemoveNodeModules($repo.FullPath, $removeLock)
        
        if ($result) {
             $view.ShowSuccess("Msg.Npm.RemovedSuccess", "node_modules removed successfully!")
             if ($removeLock) {
                 $view.ShowSuccess("Msg.Npm.RemovedLockSuccess", "package-lock.json removed successfully!")
             }
        } else {
             $view.ShowError("Error.Npm.RemoveFailed", "Error removing files.", $null)
        }
        
        Start-Sleep -Seconds 2
    }

    hidden [void] RefreshRepositoryState($context, $currentRepo) {
        $repoManager = $context.RepoManager
        $state = $context.State
        
        # Clear screen to ensure no artifacts before redraw
        $context.Console.ClearForWorkflow()

        if ($null -ne $repoManager) {
            $repoManager.LoadRepositories($context.BasePath)
            $updatedRepos = $repoManager.GetRepositories()
            $state.SetRepositories($updatedRepos)
            
            # Try to Find index of current repo to maintain selection
            $newIndex = 0
            for ($i = 0; $i -lt $updatedRepos.Count; $i++) {
                if ($updatedRepos[$i].Path -eq $currentRepo.Path) {
                    $newIndex = $i
                    break
                }
            }
            $state.SetCurrentIndex($newIndex)
        }
        $state.MarkForFullRedraw()
    }
}
