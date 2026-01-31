class NpmView {
    [IConsoleHelper] $Console
    [IUIRenderer] $Renderer
    [IOptionSelector] $OptionSelector
    [ILocalizationService] $LocalizationService
    NpmView([CommandContext]$context) {
        $this.Console = $context.Console
        $this.Renderer = $context.Renderer # Context.Renderer is now IUIRenderer so this is type safe
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
            $config = [SelectionOptions]::new()
            $config.Title = $prompt
            $config.Options = $options
            $config.ShowCurrentMarker = $false
            $config.Description = $warning
            $result = $this.OptionSelector.Show($config)
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
            $config = [SelectionOptions]::new()
            $config.Title = $prompt
            $config.Options = $options
            $config.ShowCurrentMarker = $false
            $result = $this.OptionSelector.Show($config)
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
            $npmService = [ServiceRegistry]::Resolve('NpmService')
            $jobService = [ServiceRegistry]::Resolve('JobService')
            $needsRefresh = $false
            
            if ($key -eq [Constants]::KEY_I) {
                $this.InvokeInstall($context, $currentRepo, $view, $npmService)
                $needsRefresh = $true
            }
            elseif ($key -eq [Constants]::KEY_X) {
                $needsRefresh = $this.InvokeRemove($context, $currentRepo, $view, $npmService, $jobService)
            }
            
            # Only refresh if an action was actually performed
            if ($needsRefresh) {
                $this.RefreshRepositoryState($context, $currentRepo)
            }
        }
        finally {
            $state.Resume()
        }
    }
    hidden [void] InvokeInstall($context, $repo, $view, $service) {
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
        $view.ClearAndRenderHeader("Installing", $repo)
        try {
            $view.ShowExecuting("Msg.Npm.RunningInstall", "Running npm install")
            Push-Location $repo.FullPath
            try {
                try { [Console]::CursorVisible = $true } catch {}
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
    hidden [bool] InvokeRemove($context, $repo, $view, $service, $jobService) {
        # ... validation ...
        $nodeModulesPath = Join-Path $repo.FullPath "node_modules"
        
        if (-not ($service.HasNodeModules($repo.FullPath))) {
            # ... unchanged ...
            $msgFormat = $view.GetLoc("Error.Repo.NoNodeModules", "No node_modules folder found in {0}")
            $msg = $msgFormat -f $repo.Name
            $context.Console.WriteLineColored("  [!] $msg", [Constants]::ColorWarning)
            return $false
        }

        $view.ClearAndRenderHeader("Removing", $repo)
        if (-not ($view.ConfirmRemoval("node_modules"))) {
            $view.ShowOperationCancelled()
            return $true
        }
        $removeLock = $false
        if ($service.HasPackageLock($repo.FullPath)) {
             $view.ClearAndRenderHeader("Removing", $repo)
             if ($view.ConfirmRemovePackageLock()) {
                 $removeLock = $true
             }
        }
        $view.ClearAndRenderHeader("Removing", $repo)
        Write-Host ""
        $jobScript = {
            param($path, $removeLock)
            try {
                $nm = Join-Path $path "node_modules"
                if (Test-Path $nm) {
                    $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c rmdir /s /q `"$nm`"" -NoNewWindow -Wait -PassThru
                    if ($proc.ExitCode -ne 0) {
                        throw "rmdir failed with exit code $($proc.ExitCode)"
                    }
                }
                if ($removeLock) {
                    $pl = Join-Path $path "package-lock.json"
                    if (Test-Path $pl) {
                        Remove-Item -Path $pl -Force -ErrorAction Stop
                    }
                }
                return $true
            }
            catch {
                throw $_
            }
        }
        
        $job = $jobService.StartJob($jobScript, @($repo.FullPath, $removeLock))
        
        try {
            try { [Console]::CursorVisible = $false } catch {}
            $msgBase = $view.GetLoc("Msg.Npm.Removing", "Removing node_modules")
            $msgBase = $msgBase.TrimEnd('.')
            $dots = ""
            $counter = 0
            while ($job.State -eq 'Running') {
                $step = $counter % 4
                if ($step -eq 3) { $dots = "   " } # Clear dots
                else { $dots = "." * ($step + 1) + " " * (2 - $step) }
                Write-Host "`r$msgBase$dots" -NoNewline -ForegroundColor ([Constants]::ColorWarning)
                Start-Sleep -Milliseconds 400
                $counter++
            }
            Write-Host "`r" -NoNewline
            $context.Console.ClearCurrentLine()
            
            $results = $jobService.ReceiveJob($job)
            
            $jobError = $job.ChildJobs[0].Error
            if ($job.State -eq 'Completed' -and -not $jobError) {
                 $view.ShowSuccess("Msg.Npm.RemovedSuccess", "node_modules removed successfully!")
                 if ($removeLock) {
                     $view.ShowSuccess("Msg.Npm.RemovedLockSuccess", "package-lock.json removed successfully!")
                 }
            } else {
                 $errStr = if ($jobError) { $jobError[0].ToString() } else { "Unknown error" }
                 $view.ShowError("Error.Npm.RemoveFailed", "Error removing files.", $errStr)
            }
        }
        finally {
            $jobService.RemoveJob($job, $true)
            try { [Console]::CursorVisible = $true } catch {}
        }
        Start-Sleep -Seconds 2
        return $true
    }
    hidden [void] RefreshRepositoryState($context, $currentRepo) {
        $repoManager = $context.RepoManager
        $state = $context.State
        $context.Console.ClearForWorkflow()
        
        if ($null -ne $repoManager) {
            # Force refresh of the specific repository state (CheckNodeModules etc)
            $repoManager.RefreshRepository($currentRepo)
            
            # Reload list ensuring filters apply to updated state
            $repoManager.LoadRepositories($context.BasePath)
            $updatedRepos = $repoManager.GetRepositories()
            $state.SetRepositories($updatedRepos)
            
            # Restore selection
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
