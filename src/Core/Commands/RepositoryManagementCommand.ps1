# IMPORTANT: INavigationCommand.ps1 must be loaded BEFORE this file

class RepositoryManagementCommand : INavigationCommand {
    [string] GetDescription() {
        return "Clone (C) or Delete (DELETE) repository"
    }

    [bool] CanExecute([object]$keyPress, [CommandContext]$context) {
        $key = $keyPress.VirtualKeyCode
        return $key -eq [Constants]::KEY_C -or $key -eq [Constants]::KEY_DELETE
    }

    [void] Execute([object]$keyPress, [CommandContext]$context) {
        $state = $context.State
        $repos = $state.GetRepositories()
        $currentIndex = $state.GetCurrentIndex()
        $key = $keyPress.VirtualKeyCode
        
        # Create View
        $view = [RepositoryManagementView]::new($context.Console, $context.LocalizationService, $context.Renderer, $context.OptionSelector)
        
        # Flag to track if we need to refresh repos (skip if folder delete was blocked)
        $needsRefresh = $true
        
        # Stop the navigation loop to allow interactive input
        $state.Stop()
        
        try {
            if ($key -eq [Constants]::KEY_C) {
                # Clone repository
                $this.InvokeRepositoryClone($context, $view)
            }
            elseif ($key -eq [Constants]::KEY_DELETE) {
                # Delete repository
                if ($repos.Count -gt 0) {
                    $currentRepo = $repos[$currentIndex]
                    $needsRefresh = $this.InvokeRepositoryDelete($context, $currentRepo, $view)
                }
            }
            
            # Reload repositories after clone/delete
            # Note: RepoManager.CloneRepository/DeleteRepository handles the file system,
            # but we need to refresh the in-memory list.
            # Skip refresh if folder delete was blocked (needsRefresh = false)
            
            if (-not $needsRefresh) {
                # Don't reload or redraw - just resume navigation
                return
            }
            
            $repoManager = $context.RepoManager
            if ($null -ne $repoManager) {
                # Check if we're inside a container (not at base level)
                if ($state.IsInsideContainer()) {
                    # Reload container contents
                    $currentPath = $state.GetCurrentPath()
                    $parentPath = $state.GetParentPath()
                    $repoManager.LoadContainerRepositories($currentPath, $parentPath)
                }
                else {
                    # At base level - normal reload
                    $repoManager.LoadRepositories($context.BasePath)
                }
                
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
                    # Optional: Select the new repo. 
                    # Simpler to just let user find it or implement logic to find the new repo by path
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

    hidden [void] InvokeRepositoryClone($context, [RepositoryManagementView]$view) {
        $repoManager = $context.RepoManager
        # Important: Clone into the current path where the user is navigating, not always BasePath
        $state = $context.State
        $targetPath = $state.GetCurrentPath()
        if (-not $targetPath) {
             # Fallback to base path if current path isn't set (e.g. root)
             $targetPath = $context.BasePath
        }

        # 1. View: Get Input - Pass target path to view for display
        $details = $view.GetCloneDetails($targetPath)
        if ($null -eq $details) { return }

        $url = $details.Url
        $name = $details.Name

        # 2. Service: Perform Action
        $view.ShowCloningMessage("...$name") # Using placeholder, or reconstruct path if needed
        
        try {
            [Console]::CursorVisible = $true
            
            # Call Service method - Use $targetPath instead of $basePath
            $result = $repoManager.CloneRepository($url, $name, $targetPath)
            
            # 3. View: Show Result
            $view.ShowCloneResult($result.Success, $result.Message)
        }
        finally {
             try { [Console]::CursorVisible = $false } catch {}
        }
    }

    # Returns $true if refresh is needed, $false if operation was blocked (no refresh needed)
    hidden [bool] InvokeRepositoryDelete($context, [RepositoryModel]$repository, [RepositoryManagementView]$view) {
        $repoManager = $context.RepoManager
        $console = $context.Console
        $forceDelete = $false
        
        # Show cursor for user input BEFORE clearing screen
        try { [Console]::CursorVisible = $true } catch {}
        
        try {
            # Special handling for Folder Containers (non-git folders)
            if ($repository.IsContainer) {
                $locService = $context.LocalizationService
                
                # First check if folder is empty
                $isEmpty = $repoManager.IsFolderEmpty($repository.FullPath)
                
                if (-not $isEmpty) {
                    # Folder has content - show error message inline
                    # Save current cursor position
                    $savedTop = [Console]::CursorTop
                    $savedLeft = [Console]::CursorLeft
                    
                    # Get localized message
                    $errorMsg = "Cannot delete: Folder is not empty"
                    if ($null -ne $locService) {
                        $errorMsg = $locService.Get("Folder.CannotDelete")
                    }
                    
                    try {
                        # Hide cursor during this operation
                        [Console]::CursorVisible = $false
                        
                        # Calculate target line (Status line is 2 lines above current position)
                        $targetLine = $savedTop - 2
                        if ($targetLine -ge 0) {
                            # Move to the Status line
                            [Console]::SetCursorPosition(38, $targetLine)
                            
                            # Clear rest of line first (to avoid duplicate messages)
                            $clearLength = [Console]::WindowWidth - 38 - 1
                            if ($clearLength -gt 0) {
                                Write-Host (" " * $clearLength) -NoNewline
                            }
                            
                            # Move back to write the message
                            [Console]::SetCursorPosition(38, $targetLine)
                            Write-Host " <- " -NoNewline -ForegroundColor Red
                            Write-Host $errorMsg -NoNewline -ForegroundColor Red
                            
                            # Restore cursor position
                            [Console]::SetCursorPosition($savedLeft, $savedTop)
                        }
                    }
                    catch {
                        # Silently fail - message just won't show
                    }
                    # Return false = no refresh needed, don't redraw
                    return $false
                }
                
                # Folder is empty - ask for confirmation using OptionSelector
                $optionSelector = $context.OptionSelector
                
                # Get localized question
                $question = "Delete empty folder '$($repository.Name)'?"
                if ($null -ne $locService) {
                    $question = $locService.Get("Folder.DeleteConfirm") -f $repository.Name
                }
                
                $confirmed = $optionSelector.SelectYesNo($question, $locService)
                
                if (-not $confirmed) {
                    # User cancelled
                    return $true
                }
                
                # Proceed to delete
                $result = $repoManager.DeleteFolder($repository)
                
                if (-not $result.Success) {
                    Write-Host $result.Message -ForegroundColor ([Constants]::ColorError)
                    Start-Sleep -Seconds 2
                    return $true
                }
                
                # Success - show localized folder message
                $successMsg = "Folder deleted successfully."
                if ($null -ne $locService) {
                    $successMsg = $locService.Get("Folder.DeleteSuccess")
                }
                Write-Host $successMsg -ForegroundColor ([Constants]::ColorSuccess)
                Start-Sleep -Seconds 2
                return $true
            }

            # Ensure git status is loaded
            if (-not $repository.HasGitStatusLoaded()) {
                $repoManager.LoadGitStatus($repository)
            }
            
            # Step 1: Check if repo needs attention (uncommitted changes, unpushed commits)
            if ($repository.GitStatus -and $repository.GitStatus.NeedsAttention()) {
                # Show warning and ask for confirmation
                $continueAnyway = $view.ConfirmGitStatusWarning($repository)
                if (-not $continueAnyway) { return $true }
                $forceDelete = $true
            }
            
            # Step 2: Confirm deletion by typing repo name
            $confirmed = $view.ConfirmDelete($repository)
            if (-not $confirmed) { return $true }
            
            # Step 3: Show Progress
            $view.ShowDeletingMessage()
            
            # Step 4: Service: Perform Action (with force if needed)
            $result = $repoManager.DeleteRepository($repository, $forceDelete)
            
            # Step 5: Show Result
            $view.ShowDeleteResult($result.Success, $result.Message)
            
            return $true
        }
        finally {
            # Hide cursor again
            try { [Console]::CursorVisible = $false } catch {}
        }
    }
}
