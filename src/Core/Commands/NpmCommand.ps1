# IMPORTANT: INavigationCommand.ps1 must be loaded BEFORE this file

#
# Reverted NpmCommand: Synchronous logic directly in Execute/Helpers
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
        $repoManager = $context.RepoManager
        $repos = $state.GetRepositories()
        $currentIndex = $state.GetCurrentIndex()
        
        if ($repos.Count -eq 0) { return }
        
        $currentRepo = $repos[$currentIndex]
        $key = $keyPress.VirtualKeyCode
        
        # Stop the navigation loop to allow interactive input
        $state.Stop()
        $context.Console.ShowCursor()
        
        try {
            if ($key -eq [Constants]::KEY_I) {
                $this.InvokeInstall($context, $currentRepo)
            }
            elseif ($key -eq [Constants]::KEY_X) {
                $this.InvokeRemove($context, $currentRepo)
            }
            
            # Refresh Repository Data logic
            if ($null -ne $repoManager) {
                # Force clear to ensure no artifacts
                $context.Console.ClearScreen()
                
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
        finally {
            $context.Console.HideCursor()
            $state.Resume()
        }
    }

    hidden [void] InvokeInstall([CommandContext]$context, $repo) {
        $npmService = $context.RepoManager.NpmService
        
        if (-not ($npmService.HasPackageJson($repo.FullPath))) {
             $context.Console.ClearScreen()
             Write-Host "No package.json found in repository." -ForegroundColor ([Constants]::ColorWarning)
             Start-Sleep -Seconds 2
             return
        }

        $npmPath = $npmService.GetNpmExecutablePath()
        if (-not $npmPath) {
             $context.Console.ClearScreen()
             Write-Host "Error: 'npm' command not found." -ForegroundColor ([Constants]::ColorError)
             Start-Sleep -Seconds 2
             return
        }

        $context.Console.ClearScreen()
        Write-Host "=======================================================" -ForegroundColor ([Constants]::ColorSeparator)
        Write-Host "    NPM INSTALL" -ForegroundColor ([Constants]::ColorHeader)
        Write-Host "=======================================================" -ForegroundColor ([Constants]::ColorSeparator)
        Write-Host "Repository: " -NoNewline -ForegroundColor ([Constants]::ColorPrompt)
        Write-Host $repo.Name -ForegroundColor ([Constants]::ColorValue)
        Write-Host "=======================================================" -ForegroundColor ([Constants]::ColorSeparator)
        Write-Host ""
        
        # Native execution with output streaming
        Push-Location $repo.FullPath
        try {
            Write-Host "Running npm install..." -ForegroundColor ([Constants]::ColorWarning)
            # cmd /c ensures we see the output naturally
            Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$npmPath`" install" -WorkingDirectory $repo.FullPath -NoNewWindow -Wait
            
            Write-Host ""
            Write-Host "Done." -ForegroundColor ([Constants]::ColorSuccess)
            Start-Sleep -Seconds 2
        }
        finally {
            Pop-Location
        }
    }

    hidden [void] InvokeRemove([CommandContext]$context, $repo) {
        $npmService = $context.RepoManager.NpmService
        $nodeModulesPath = Join-Path $repo.FullPath "node_modules"
        
        if (-not (Test-Path $nodeModulesPath)) {
            $context.Console.ClearScreen()
            Write-Host "No node_modules folder found in this repository." -ForegroundColor ([Constants]::ColorWarning)
            Start-Sleep -Seconds 2
            return
        }
        
        $context.Console.ClearScreen()
        Write-Host "=======================================================" -ForegroundColor ([Constants]::ColorSeparator)
        Write-Host "    REMOVE NODE_MODULES" -ForegroundColor ([Constants]::ColorHeader)
        Write-Host "=======================================================" -ForegroundColor ([Constants]::ColorSeparator)
        Write-Host "Repository: " -NoNewline -ForegroundColor ([Constants]::ColorPrompt)
        Write-Host $repo.Name -ForegroundColor ([Constants]::ColorValue)
        Write-Host "=======================================================" -ForegroundColor ([Constants]::ColorSeparator)
        Write-Host ""
        Write-Host "This will delete the node_modules folder." -ForegroundColor ([Constants]::ColorWarning)
        Write-Host "Continue? (Y/n): " -NoNewline -ForegroundColor ([Constants]::ColorLabel)
        
        $confirm = Read-Host
        
        if ($confirm -eq '' -or $confirm -eq 'Y' -or $confirm -eq 'y') {
            # Ask about package-lock.json
            $packageLockPath = Join-Path $repo.FullPath "package-lock.json"
            $removePackageLock = $false
            
            if (Test-Path $packageLockPath) {
                Write-Host ""
                Write-Host "Do you also want to remove package-lock.json? (y/N): " -NoNewline -ForegroundColor ([Constants]::ColorHighlight)
                $packageLockConfirm = Read-Host
                $removePackageLock = ($packageLockConfirm -eq 'y' -or $packageLockConfirm -eq 'Y')
            }
            
            Write-Host ""
            Write-Host "Removing node_modules..." -ForegroundColor ([Constants]::ColorWarning)
            
            # Using NpmService logic for actual removal
            $result = $npmService.RemoveNodeModules($repo.FullPath, $removePackageLock)
            
            Write-Host ""
            if ($result) {
                Write-Host "node_modules removed successfully!" -ForegroundColor ([Constants]::ColorSuccess)
            } else {
                Write-Host "Error removing node_modules." -ForegroundColor ([Constants]::ColorError)
            }
            Start-Sleep -Seconds 2
        } else {
            Write-Host "Operation cancelled." -ForegroundColor ([Constants]::ColorWarning)
            Start-Sleep -Seconds 1
        }
    }
}
