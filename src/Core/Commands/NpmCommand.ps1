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
            # If the service returns the key wrapped in brackets (missing translation), use our default
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

    [void] ShowPreparingAnimation([string]$message) {
        $cursorTop = $global:Host.UI.RawUI.CursorPosition.Y
        $cursorLeft = $global:Host.UI.RawUI.CursorPosition.X
        
        $dotCount = 0
        $maxIterations = 5  # Show animation for approx 2 seconds
        
        for ($i = 0; $i -lt $maxIterations; $i++) {
             try { $global:Host.UI.RawUI.CursorPosition = @{ X = $cursorLeft; Y = $cursorTop } } catch {}
             $dots = "." * $dotCount
             Write-Host "$message$dots".PadRight(50) -NoNewline -ForegroundColor ([Constants]::ColorWarning)
             $dotCount = ($dotCount + 1) % 4
             Start-Sleep -Milliseconds 400
        }
        
        # Final clean state
        try { $global:Host.UI.RawUI.CursorPosition = @{ X = $cursorLeft; Y = $cursorTop } } catch {}
        Write-Host "$message...".PadRight(50) -ForegroundColor ([Constants]::ColorWarning)
        Write-Host ""
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
            $result = $this.OptionSelector.ShowSelection($prompt, $options, $false, "Cancel", $false, $warning)
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
            $result = $this.OptionSelector.ShowSelection($prompt, $options, $false, "Cancel", $false, $null)
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
            # Display Preparing Animation
            $msgRunning = $view.GetLoc("Msg.Npm.RunningInstall", "Running npm install")
            $view.ShowPreparingAnimation($msgRunning)
            
            Push-Location $repo.FullPath
            try {
                try { [Console]::CursorVisible = $true } catch {}
                
            # Use Start-Process with cmd /c to ensure native console experience (colors, progress bars)
            # This bypasses PowerShell's stream handling which causes red text or monochrome output
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

        # 2. Confirmation
        $view.ClearAndRenderHeader("Removing", $repo)
        if (-not ($view.ConfirmRemoval("node_modules"))) {
            $view.ShowOperationCancelled()
            return
        }

        # Check for package-lock.json
        $removeLock = $false
        $lockPath = Join-Path $repo.FullPath "package-lock.json"
        
        if ($service.HasPackageLock($repo.FullPath)) {
             if ($view.ConfirmRemovePackageLock()) {
                 $removeLock = $true
             }
        }

        # 3. Execution (Background Job for Animation)
        $view.ClearAndRenderHeader("Removing", $repo)
        Write-Host ""

        # Using a job because deletion can take time and we want to animate
        $scriptBlock = {
            param($path, $remLock, $lPath)
            Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
            if ($remLock -and (Test-Path $lPath)) {
                Remove-Item -Path $lPath -Force -ErrorAction Stop
            }
        }

        $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $nodeModulesPath, $removeLock, $lockPath
        
        # Run Animation while waiting
        $msgRunning = $view.GetLoc("Msg.Npm.Removing", "Removing node_modules")
        $this.WaitForJobWithAnimation($job, $msgRunning)

        # Process Result
        $result = Receive-Job -Job $job -ErrorAction SilentlyContinue
        
        # Wait-Job ensures we get the state correctly if loop exited early
        $null = Wait-Job -Job $job -Timeout 1
        
        if ($job.State -eq 'Completed' -and -not $job.ChildJobs[0].Error) {
             $view.ShowSuccess("Msg.Npm.RemovedSuccess", "node_modules removed successfully!")
             if ($removeLock) {
                 $view.ShowSuccess("Msg.Npm.RemovedLockSuccess", "package-lock.json removed successfully!")
             }
        } else {
             $err = $job.ChildJobs[0].Error
             $view.ShowError("Error.Npm.RemoveFailed", "Error removing files: ", "$err")
        }
        
        Remove-Job -Job $job
        Start-Sleep -Seconds 2
    }

    hidden [void] WaitForJobWithAnimation($job, $message) {
        $cursorTop = $global:Host.UI.RawUI.CursorPosition.Y
        $cursorLeft = $global:Host.UI.RawUI.CursorPosition.X
        $dotCount = 0
        
        while ($job.State -eq 'Running') {
            try { $global:Host.UI.RawUI.CursorPosition = @{ X = $cursorLeft; Y = $cursorTop } } catch {}
            
            $dots = "." * $dotCount
            Write-Host "$message$dots".PadRight(50) -NoNewline -ForegroundColor ([Constants]::ColorWarning)
            
            $dotCount = ($dotCount + 1) % 4
            Start-Sleep -Milliseconds 400
        }

        # Final cleanup line
        try { $global:Host.UI.RawUI.CursorPosition = @{ X = $cursorLeft; Y = $cursorTop } } catch {}
        Write-Host "".PadRight(60) -NoNewline
        try { $global:Host.UI.RawUI.CursorPosition = @{ X = $cursorLeft; Y = $cursorTop } } catch {}
    }

    hidden [void] RefreshRepositoryState($context, $currentRepo) {
        $repoManager = $context.RepoManager
        $state = $context.State
        
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

