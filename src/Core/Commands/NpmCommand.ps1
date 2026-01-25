# IMPORTANT: INavigationCommand.ps1 must be loaded BEFORE this file

class NpmCommand : INavigationCommand {
    [string] GetDescription() {
        return "Install npm (I) or Remove node_modules (X)"
    }

    [bool] CanExecute([object]$keyPress, [hashtable]$context) {
        $key = $keyPress.VirtualKeyCode
        return $key -eq [Constants]::KEY_I -or $key -eq [Constants]::KEY_X
    }

    [void] Execute([object]$keyPress, [hashtable]$context) {
        $state = $context.State
        $repos = $state.GetRepositories()
        $currentIndex = $state.GetCurrentIndex()
        
        if ($repos.Count -eq 0) { return }
        
        $currentRepo = $repos[$currentIndex]
        $key = $keyPress.VirtualKeyCode
        
        # Stop the navigation loop to allow interactive input
        $state.Stop()
        
        try {
            if ($key -eq [Constants]::KEY_I) {
                # Install node_modules
                $this.InvokeNpmInstall($context, $currentRepo)
            }
            elseif ($key -eq [Constants]::KEY_X) {
                # Remove node_modules
                $this.InvokeNodeModulesRemove($context, $currentRepo)
            }
            
            # Reload repositories to reflect changes (e.g., node_modules presence)
            $repoManager = $context.RepoManager
            if ($null -ne $repoManager) {
                $repoManager.LoadRepositories($context.BasePath)
                $updatedRepos = $repoManager.GetRepositories()
                $state.SetRepositories($updatedRepos)
                
                # Try to maintain selection on the same repository
                $newIndex = 0
                for ($i = 0; $i -lt $updatedRepos.Count; $i++) {
                    if ($updatedRepos[$i].Path -eq $currentRepo.Path) {
                        $newIndex = $i
                        break
                    }
                }
                $state.SetCurrentIndex($newIndex)
            }
            
            # Mark for full redraw
            $state.MarkForFullRedraw()
        }
        finally {
            # Resume navigation loop
            $state.Resume()
        }
    }

    hidden [void] InvokeNpmInstall($context, $Repository) {
        $NpmService = $context.NpmService
        $Console = $context.Console
        $LocalizationService = $context.LocalizationService
        $Renderer = $context.Renderer

        # Helper for localization
        $GetLoc = { param($key, $def) if ($LocalizationService) { return $LocalizationService.Get($key) } return $def }

        # Check if package.json exists
        $packageJsonPath = Join-Path $Repository.FullPath "package.json"
        if (-not (Test-Path $packageJsonPath)) {
            $Console.ClearForWorkflow()
            Write-Host (& $GetLoc "Error.Repo.NoPackageJson" "No package.json found in this repository.") -ForegroundColor ([Constants]::ColorError)
            Start-Sleep -Seconds 2
            return
        }

        # Check if npm is available using smart detection from NpmService
        $npmPath = $NpmService.GetNpmExecutablePath()
        
        if (-not $npmPath) {
            $Console.ClearForWorkflow()
            $Renderer.RenderError("npm not found")
            Write-Host ""
            Write-Host (& $GetLoc "Error.Npm.NotFound" "Error: 'npm' command was not found in your PATH or standard locations.") -ForegroundColor ([Constants]::ColorError)
            Write-Host ""
            Write-Host (& $GetLoc "Error.Npm.InstallNode" "To use this feature, you need to install Node.js.") -ForegroundColor ([Constants]::ColorWarning)
            Write-Host (& $GetLoc "Error.Npm.InstallLink" "Please download and install it from: https://nodejs.org/") -ForegroundColor ([Constants]::ColorValue)
            Write-Host (& $GetLoc "Error.Npm.NvmHint" "If you use NVM, ensure a version is currently selected ('nvm use ...').") -ForegroundColor ([Constants]::ColorGray)
            Write-Host ""
            Start-Sleep -Seconds 5
            return
        }
        
        $Console.ClearForWorkflow()
        $Renderer.RenderWorkflowHeader((& $GetLoc "Msg.Npm.Installing" "INSTALL DEPENDENCIES"), $Repository)
        
        # Show brief animated "preparing" message
        $cursorTop = $global:Host.UI.RawUI.CursorPosition.Y
        $cursorLeft = $global:Host.UI.RawUI.CursorPosition.X
        
        $dotCount = 0
        $iterations = 0
        $maxIterations = 5  # Show animation for ~2 seconds
        
        $locRunMsg = & $GetLoc "Msg.Npm.RunningInstall" "Running npm install"

        while ($iterations -lt $maxIterations) {
            # Restore cursor position
            try {
                $global:Host.UI.RawUI.CursorPosition = @{ X = $cursorLeft; Y = $cursorTop }
            } catch {}
            
            # Create the dots string (0 to 3 dots)
            $dots = "." * $dotCount
            
            # Display progress indicator
            $message = $locRunMsg + $dots
            Write-Host $message.PadRight(50) -NoNewline -ForegroundColor ([Constants]::ColorWarning)
            
            # Increment dot count and cycle back to 0 after 3 dots
            $dotCount = ($dotCount + 1) % 4
            $iterations++
            
            Start-Sleep -Milliseconds 400
        }
        
        # Leave the final static message visible
        try {
            $global:Host.UI.RawUI.CursorPosition = @{ X = $cursorLeft; Y = $cursorTop }
        } catch {}
        Write-Host ($locRunMsg + "...").PadRight(50) -ForegroundColor ([Constants]::ColorWarning)
        Write-Host ""
        
        Push-Location $Repository.FullPath
        try {
            # Ensure cursor is visible for npm output
            try { [Console]::CursorVisible = $true } catch {}

            # Force npm output to be visible by calling it with explicit output redirection
            & $npmPath install *>&1 | Write-Host
            
            try { [Console]::CursorVisible = $false } catch {}
            
            Write-Host ""
            Write-Host (& $GetLoc "Msg.Npm.Success" "Dependencies installed successfully!") -ForegroundColor ([Constants]::ColorSuccess)
            Start-Sleep -Seconds 2
        }
        catch {
            try { [Console]::CursorVisible = $false } catch {}
            Write-Host ""
            Write-Host "Error installing dependencies: $_" -ForegroundColor ([Constants]::ColorError)
            Start-Sleep -Seconds 3
        }
        finally {
            Pop-Location
        }
    }

    hidden [void] InvokeNodeModulesRemove($context, $Repository) {
        $RepoManager = $context.RepoManager
        $Console = $context.Console
        $LocalizationService = $context.LocalizationService
        $OptionSelector = $context.OptionSelector
        $NpmService = $context.NpmService
        $Renderer = $context.Renderer

        # Helper for localization
        $GetLoc = { param($key, $def) if ($LocalizationService) { return $LocalizationService.Get($key) } return $def }

        $nodeModulesPath = Join-Path $Repository.FullPath "node_modules"
        
        if (-not (Test-Path $nodeModulesPath)) {
            $Console.ClearForWorkflow()
            $msg = & $GetLoc "Error.Repo.NoNodeModules" "No node_modules folder found in {0}"
            Write-Host ($msg -f $Repository.Name) -ForegroundColor ([Constants]::ColorWarning)
            Start-Sleep -Seconds 2
            return
        }
        
        $Console.ClearForWorkflow()
        $header = & $GetLoc "Msg.Npm.Removing" "REMOVE NODE_MODULES"
        $Renderer.RenderWorkflowHeader($header, $Repository)

        # Confirm
        $continue = $false
        $warningMsg = & $GetLoc "Msg.Npm.DeleteWarning" "This will delete the node_modules folder."
        $prompt = & $GetLoc "Prompt.Continue" "Continue?"

        if ($OptionSelector) {
            $continue = $this.ConfirmSelection($prompt, $OptionSelector, $LocalizationService, $false, $warningMsg)
        } else {
            Write-Host $warningMsg -ForegroundColor ([Constants]::ColorWarning)
            Write-Host ""
            $continue = $Console.ConfirmAction($prompt, $false)
        }

        if ($continue) {
            # Ask about package-lock.json
            $packageLockPath = Join-Path $Repository.FullPath "package-lock.json"
            $removePackageLock = $false
            
            if (Test-Path $packageLockPath) {
                $lockPrompt = & $GetLoc "Msg.Npm.RemoveLockPrompt" "Do you also want to remove package-lock.json?"
                
                if ($OptionSelector) {
                    $removePackageLock = $this.ConfirmSelection($lockPrompt, $OptionSelector, $LocalizationService, $false, $null)
                } else {
                    Write-Host ""
                    $removePackageLock = $Console.ConfirmAction($lockPrompt, $false)
                }
            }
            
            $Console.ClearForWorkflow()
            $Renderer.RenderWorkflowHeader($header, $Repository)
            Write-Host ""
            
            # Remove with animation job
            try {
                # Save cursor position
                $cursorTop = $global:Host.UI.RawUI.CursorPosition.Y
                $cursorLeft = $global:Host.UI.RawUI.CursorPosition.X
                
                # Start the removal in a background job
                $job = Start-Job -ScriptBlock {
                    param($path, $remLock, $lockPath)
                    Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
                    if ($remLock -and (Test-Path $lockPath)) {
                        Remove-Item -Path $lockPath -Force -ErrorAction Stop
                    }
                } -ArgumentList $nodeModulesPath, $removePackageLock, $packageLockPath
                
                # Show animated progress while job runs
                $dotCount = 0
                $maxDots = 3
                while ($job.State -eq 'Running') {
                    # Restore cursor position
                     try {
                        $global:Host.UI.RawUI.CursorPosition = @{ X = $cursorLeft; Y = $cursorTop }
                    } catch {}
                    
                    # Create the dots string (0 to 3 dots)
                    $dots = "." * $dotCount
                    
                    # Display progress indicator with padding to clear previous text
                    $message = "Removing node_modules" + $dots
                    Write-Host $message.PadRight(50) -NoNewline -ForegroundColor ([Constants]::ColorWarning)
                    
                    # Increment dot count and cycle back to 0 after maxDots
                    $dotCount = ($dotCount + 1) % ($maxDots + 1)
                    
                    Start-Sleep -Milliseconds 400
                }
                
                # Wait for job to complete and get result
                $jobResult = Wait-Job -Job $job
                
                # Pre-declare error var to satisfy parser
                $jobErrors = $null
                $jobErrorOutput = Receive-Job -Job $job -ErrorAction SilentlyContinue -ErrorVariable jobErrors
                
                Remove-Job -Job $job
                
                # Clear the progress line
                 try {
                    $global:Host.UI.RawUI.CursorPosition = @{ X = $cursorLeft; Y = $cursorTop }
                } catch {}
                Write-Host (" " * 50) -NoNewline
                 try {
                    $global:Host.UI.RawUI.CursorPosition = @{ X = $cursorLeft; Y = $cursorTop }
                } catch {}
                
                if ($jobResult.State -eq 'Completed' -and ($null -eq $jobErrors -or $jobErrors.Count -eq 0)) {
                     Write-Host (& $GetLoc "Msg.Npm.RemovedSuccess" "node_modules removed successfully!") -ForegroundColor ([Constants]::ColorSuccess)
                     if ($removePackageLock) {
                        Write-Host (& $GetLoc "Msg.Npm.RemovedLockSuccess" "package-lock.json removed successfully!") -ForegroundColor ([Constants]::ColorSuccess)
                     }
                }
                else {
                    Write-Host "Error removing node_modules: 	$jobErrors" -ForegroundColor ([Constants]::ColorError)
                }
            }
            catch {
                Write-Host "Error removing node_modules: $_" -ForegroundColor ([Constants]::ColorError)
            }

            Start-Sleep -Seconds 2
        } else {
            Write-Host (& $GetLoc "Msg.ActionCancelled" "Operation cancelled.") -ForegroundColor ([Constants]::ColorWarning)
            Start-Sleep -Seconds 1
        }
    }
    hidden [bool] ConfirmSelection($title, $OptionSelector, $LocalizationService, $defaultYes, $description) {
        $yesText = if ($LocalizationService) { $LocalizationService.Get("Prompt.Yes") } else { "Yes" }
        $noText = if ($LocalizationService) { $LocalizationService.Get("Prompt.No") } else { "No" }
        
        $options = @(
            @{ DisplayText = $yesText; Value = $true },
            @{ DisplayText = $noText; Value = $false }
        )
        
        $result = $OptionSelector.ShowSelection($title, $options, $defaultYes, "Cancel", $false, $description)
        
        if ($null -eq $result) { return $false }
        return $result
    }
}

