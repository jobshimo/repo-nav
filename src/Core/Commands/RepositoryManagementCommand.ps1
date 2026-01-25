# IMPORTANT: INavigationCommand.ps1 must be loaded BEFORE this file

class RepositoryManagementCommand : INavigationCommand {
    [string] GetDescription() {
        return "Clone (C) or Delete (DELETE) repository"
    }

    [bool] CanExecute([object]$keyPress, [hashtable]$context) {
        $key = $keyPress.VirtualKeyCode
        return $key -eq [Constants]::KEY_C -or $key -eq [Constants]::KEY_DELETE
    }

    [void] Execute([object]$keyPress, [hashtable]$context) {
        $state = $context.State
        $repos = $state.GetRepositories()
        $currentIndex = $state.GetCurrentIndex()
        $key = $keyPress.VirtualKeyCode
        
        # Stop the navigation loop to allow interactive input
        $state.Stop()
        
        try {
            if ($key -eq [Constants]::KEY_C) {
                # Clone repository
                $this.InvokeRepositoryClone($context)
            }
            elseif ($key -eq [Constants]::KEY_DELETE) {
                # Delete repository
                if ($repos.Count -gt 0) {
                    $currentRepo = $repos[$currentIndex]
                    $this.InvokeRepositoryDelete($context, $currentRepo)
                }
            }
            
            # Reload repositories after clone/delete
            $repoManager = $context.RepoManager
            if ($null -ne $repoManager) {
                $repoManager.LoadRepositories($context.BasePath)
                $updatedRepos = $repoManager.GetRepositories()
                $state.SetRepositories($updatedRepos)
                
                # Adjust selection after deletion or addition
                if ($key -eq [Constants]::KEY_DELETE) {
                    # If we deleted the last item, move selection up
                    if ($currentIndex -ge $updatedRepos.Count -and $updatedRepos.Count -gt 0) {
                        $state.SetCurrentIndex($updatedRepos.Count - 1)
                    }
                    elseif ($updatedRepos.Count -eq 0) {
                        $state.SetCurrentIndex(0)
                    }
                    # Otherwise keep current index (which now points to the next item)
                }
                elseif ($key -eq [Constants]::KEY_C) {
                    # Select the new repo if possible? 
                    # For now just reload.
                }
            }
            
            # Mark for full redraw
            $state.MarkForFullRedraw()
        }
        finally {
            # Resume navigation loop
            $state.Resume()
        }
    }

    hidden [void] InvokeRepositoryClone($context) {
        $RepoManager = $context.RepoManager
        $BasePath = $context.BasePath
        $Console = $context.Console
        $LocalizationService = $context.LocalizationService

        # Helper for localization
        $GetLoc = { param($key, $def) if ($LocalizationService) { return $LocalizationService.Get($key) } return $def }

        $Console.ClearForWorkflow()
        $header = & $GetLoc "Repo.CloneTitle" "CLONE REPOSITORY"
        Write-Host "=======================================================" -ForegroundColor ([Constants]::ColorSeparator)
        Write-Host "    $header" -ForegroundColor ([Constants]::ColorHeader)
        Write-Host "=======================================================" -ForegroundColor ([Constants]::ColorSeparator)
        Write-Host ""
        
        Write-Host "GitHub URL (https://... or git@...): " -NoNewline -ForegroundColor ([Constants]::ColorPrompt)
        $url = Read-Host
        
        if ([string]::IsNullOrWhiteSpace($url)) {
            Write-Host "Operation cancelled." -ForegroundColor ([Constants]::ColorWarning)
            Start-Sleep -Seconds 1
            return
        }
        
        # Extract name from URL
        $repoName = $url.Split('/')[-1].Replace('.git', '')
        
        Write-Host "Target folder name (Enter = '$repoName'): " -NoNewline -ForegroundColor ([Constants]::ColorPrompt)
        $customName = Read-Host
        
        if (-not [string]::IsNullOrWhiteSpace($customName)) {
            $repoName = $customName
        }
        
        $targetPath = Join-Path $BasePath $repoName
        
        if (Test-Path $targetPath) {
            Write-Host "Error: Folder '$repoName' already exists." -ForegroundColor ([Constants]::ColorError)
            Start-Sleep -Seconds 2
            return
        }
        
        Write-Host ""
        Write-Host "Cloning into '$targetPath'..." -ForegroundColor ([Constants]::ColorHighlight)
        
        # Show cursor for git output
        try {
            [Console]::CursorVisible = $true
        } catch {}
        
        try {
            git clone $url $targetPath
            
            if ($?) {
                Write-Host ""
                Write-Host "Repository cloned successfully!" -ForegroundColor ([Constants]::ColorSuccess)
            } else {
                Write-Host ""
                Write-Host "Failed to clone repository." -ForegroundColor ([Constants]::ColorError)
            }
        }
        catch {
            Write-Host "Error executing git clone: $_" -ForegroundColor ([Constants]::ColorError)
        }
        finally {
            try { [Console]::CursorVisible = $false } catch {}
        }
        
        Start-Sleep -Seconds 2
    }

    hidden [void] InvokeRepositoryDelete($context, [RepositoryModel]$Repository) {
        $RepoManager = $context.RepoManager
        $Console = $context.Console
        $LocalizationService = $context.LocalizationService
        $OptionSelector = $context.OptionSelector

        # Helper for localization
        $GetLoc = { param($key, $def) if ($LocalizationService) { return $LocalizationService.Get($key) } return $def }

        $Console.ClearForWorkflow()
        $header = & $GetLoc "Repo.DeleteTitle" "DELETE REPOSITORY"
        Write-Host "=======================================================" -ForegroundColor ([Constants]::ColorSeparator)
        Write-Host "    $header" -ForegroundColor ([Constants]::ColorHeader)
        Write-Host "=======================================================" -ForegroundColor ([Constants]::ColorSeparator)
        Write-Host "Repository: " -NoNewline -ForegroundColor ([Constants]::ColorPrompt)
        Write-Host $Repository.Name -ForegroundColor ([Constants]::ColorValue)
        Write-Host "Path:       " -NoNewline -ForegroundColor ([Constants]::ColorPrompt)
        Write-Host $Repository.FullPath -ForegroundColor ([Constants]::ColorValue)
        Write-Host "=======================================================" -ForegroundColor ([Constants]::ColorSeparator)
        Write-Host ""
        
        $warningMsg = & $GetLoc "Repo.DeleteWarning" "WARNING: This will permanently delete the folder and all contents!"
        $confirmMsg = & $GetLoc "Prompt.DeleteConfirm" "Type 'DELETE' to confirm"
        
        Write-Host $warningMsg -ForegroundColor Red
        Write-Host ""
        Write-Host "$confirmMsg : " -NoNewline -ForegroundColor Red
        
        $confirmation = Read-Host
        
        if ($confirmation -eq "DELETE") {
            try {
                Write-Host "Deleting..." -ForegroundColor ([Constants]::ColorWarning)
                Remove-Item -Path $Repository.FullPath -Recurse -Force -ErrorAction Stop
                
                # Also remove from aliases if exists
                if ($Repository.HasAlias) {
                    $RepoManager.RemoveAlias($Repository)
                }
                
                Write-Host "Repository deleted successfully." -ForegroundColor ([Constants]::ColorSuccess)
            }
            catch {
                Write-Host "Error deleting repository: $_" -ForegroundColor ([Constants]::ColorError)
                Write-Host "Check if files are open in another program." -ForegroundColor ([Constants]::ColorGray)
            }
        } else {
            Write-Host "Operation cancelled." -ForegroundColor ([Constants]::ColorWarning)
        }
        
        Start-Sleep -Seconds 2
    }
}
