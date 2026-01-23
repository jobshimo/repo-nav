<#
.SYNOPSIS
    NavigatorController - Main application orchestrator
    
.DESCRIPTION
    Following SOLID principles:
    - SRP: Only manages navigation flow and user interaction
    - DIP: Depends on all service abstractions
    - OCP: Can be extended with new commands
    
    This is the main controller that:
    - Manages application state
    - Handles user input loop
    - Coordinates UI rendering
    - Delegates operations to RepositoryManager
    - Provides the main navigation experience
#>

class NavigatorController {
    # Dependencies (injected)
    [RepositoryManager] $RepoManager
    [UIRenderer] $Renderer
    [ConsoleHelper] $Console
    [ColorSelector] $ColorSelector
    
    # Application state
    [int] $SelectedIndex
    [bool] $Running
    [string] $BasePath
    
    # Constructor with full dependency injection
    NavigatorController(
        [RepositoryManager]$repoManager,
        [UIRenderer]$renderer,
        [ConsoleHelper]$console,
        [ColorSelector]$colorSelector,
        [string]$basePath
    ) {
        $this.RepoManager = $repoManager
        $this.Renderer = $renderer
        $this.Console = $console
        $this.ColorSelector = $colorSelector
        $this.BasePath = $basePath
        $this.SelectedIndex = 0
        $this.Running = $false
    }
    
    # Start the navigator
    [void] Start() {
        # Load repositories
        $this.RepoManager.LoadRepositories($this.BasePath)
        
        $repos = $this.RepoManager.GetRepositories()
        if ($repos.Count -eq 0) {
            $this.Renderer.RenderError("No repositories found in this folder.")
            return
        }
        
        $this.Running = $true
        $this.SelectedIndex = 0
        
        try {
            $this.Console.HideCursor()
            $this.RenderFullScreen()
            $this.InputLoop()
        }
        finally {
            $this.Console.ShowCursor()
        }
    }
    
    # Main input loop
    [void] InputLoop() {
        $previousIndex = $this.SelectedIndex
        
        while ($this.Running) {
            $key = $this.Console.ReadKey()
            
            switch ($key.VirtualKeyCode) {
                ([Constants]::KEY_UP_ARROW) {
                    $this.HandleNavigationUp()
                    $this.UpdateSelection($previousIndex)
                    $previousIndex = $this.SelectedIndex
                }
                
                ([Constants]::KEY_DOWN_ARROW) {
                    $this.HandleNavigationDown()
                    $this.UpdateSelection($previousIndex)
                    $previousIndex = $this.SelectedIndex
                }
                
                ([Constants]::KEY_ENTER) {
                    $this.HandleEnter()
                }
                
                ([Constants]::KEY_E) {
                    $this.HandleSetAlias()
                }
                
                ([Constants]::KEY_R) {
                    $this.HandleRemoveAlias()
                }
                
                ([Constants]::KEY_I) {
                    $this.HandleInstallDependencies()
                }
                
                ([Constants]::KEY_X) {
                    $this.HandleRemoveNodeModules()
                }
                
                ([Constants]::KEY_C) {
                    $this.HandleCloneRepository()
                }
                
                ([Constants]::KEY_DELETE) {
                    $this.HandleDeleteRepository()
                }
                
                ([Constants]::KEY_L) {
                    $this.HandleLoadGitStatusCurrent()
                }
                
                ([Constants]::KEY_G) {
                    $this.HandleLoadGitStatusAll()
                }
                
                ([Constants]::KEY_Q) {
                    $this.HandleQuit()
                }
                
                ([Constants]::KEY_ESC) {
                    $this.HandleQuit()
                }
            }
        }
    }
    
    # Render full screen
    [void] RenderFullScreen() {
        $this.Console.ClearScreen()
        $this.Renderer.RenderHeader("REPOSITORY NAVIGATOR")
        $this.Renderer.RenderMenu()
        
        $repos = $this.RepoManager.GetRepositories()
        for ($i = 0; $i -lt $repos.Count; $i++) {
            $this.Renderer.RenderRepositoryItem($repos[$i], ($i -eq $this.SelectedIndex))
        }
        
        Write-Host ""
        $this.RenderFooter()
    }
    
    # Update only selection (optimized)
    [void] UpdateSelection([int]$previousIndex) {
        $repos = $this.RepoManager.GetRepositories()
        $startLine = [Constants]::CursorStartLine
        
        # Update previous item (deselect)
        if ($previousIndex -ge 0 -and $previousIndex -lt $repos.Count) {
            $this.Renderer.UpdateRepositoryItemAt(($startLine + $previousIndex), $repos[$previousIndex], $false)
        }
        
        # Update current item (select)
        $this.Renderer.UpdateRepositoryItemAt(($startLine + $this.SelectedIndex), $repos[$this.SelectedIndex], $true)
        
        # Update footer
        $this.UpdateFooter()
    }
    
    # Render footer
    [void] RenderFooter() {
        $repos = $this.RepoManager.GetRepositories()
        $loadedCount = $this.RepoManager.GetLoadedGitStatusCount()
        $this.Renderer.RenderGitStatusFooter($repos[$this.SelectedIndex], $repos.Count, $loadedCount)
    }
    
    # Update footer only
    [void] UpdateFooter() {
        $repos = $this.RepoManager.GetRepositories()
        $footerLine = [Constants]::CursorStartLine + $repos.Count + 1
        
        $this.Console.SetCursorPosition(0, $footerLine)
        $loadedCount = $this.RepoManager.GetLoadedGitStatusCount()
        $this.Renderer.RenderGitStatusFooter($repos[$this.SelectedIndex], $repos.Count, $loadedCount)
    }
    
    # Navigation handlers
    [void] HandleNavigationUp() {
        $repos = $this.RepoManager.GetRepositories()
        if ($this.SelectedIndex -gt 0) {
            $this.SelectedIndex--
        } else {
            $this.SelectedIndex = $repos.Count - 1
        }
    }
    
    [void] HandleNavigationDown() {
        $repos = $this.RepoManager.GetRepositories()
        if ($this.SelectedIndex -lt ($repos.Count - 1)) {
            $this.SelectedIndex++
        } else {
            $this.SelectedIndex = 0
        }
    }
    
    # Action handlers
    [void] HandleEnter() {
        $repos = $this.RepoManager.GetRepositories()
        $selectedRepo = $repos[$this.SelectedIndex]
        
        $this.Console.ClearScreen()
        $this.Renderer.RenderSuccess("Opening: $($selectedRepo.Name)")
        Set-Location $selectedRepo.FullPath
        $this.Running = $false
    }
    
    [void] HandleSetAlias() {
        $repos = $this.RepoManager.GetRepositories()
        $selectedRepo = $repos[$this.SelectedIndex]
        
        # Get current alias or default
        $currentAlias = if ($selectedRepo.HasAlias) { $selectedRepo.AliasInfo.Alias } else { "" }
        $currentColor = if ($selectedRepo.HasAlias) { $selectedRepo.AliasInfo.Color } else { [ColorPalette]::DefaultAliasColor }
        
        # Show alias input screen
        $this.Console.ClearScreen()
        $this.Renderer.RenderHeader("SET ALIAS")
        Write-Host "Repository: " -NoNewline -ForegroundColor Yellow
        Write-Host $selectedRepo.Name -ForegroundColor White
        Write-Host ("=" * 55) -ForegroundColor Cyan
        Write-Host ""
        
        if ($currentAlias) {
            Write-Host "Current alias: " -NoNewline -ForegroundColor Gray
            Write-Host $currentAlias -ForegroundColor $currentColor
            Write-Host ""
            Write-Host "[current: $currentAlias]" -ForegroundColor DarkGray
            Write-Host "New alias (or press Enter to keep current): " -NoNewline -ForegroundColor Gray
        } else {
            Write-Host "Enter alias (no spaces): " -NoNewline -ForegroundColor Gray
        }
        
        $this.Console.ShowCursor()
        $alias = Read-Host
        $this.Console.HideCursor()
        
        # If empty and has current, keep it
        if ([string]::IsNullOrWhiteSpace($alias) -and $currentAlias) {
            $alias = $currentAlias
        }
        
        # Validate
        $aliasInfo = [AliasInfo]::new($alias)
        if (-not $aliasInfo.IsValid()) {
            $this.Renderer.RenderError("Invalid alias format (no spaces allowed)")
            Start-Sleep -Seconds 2
            $this.RenderFullScreen()
            return
        }
        
        # Select color
        $selectedColor = $this.ColorSelector.SelectColor($currentColor)
        $aliasInfo = [AliasInfo]::new($alias, $selectedColor)
        
        # Save
        if ($this.RepoManager.SetAlias($selectedRepo, $aliasInfo)) {
            $this.Console.ClearScreen()
            $this.Renderer.RenderSuccess("Alias saved successfully!")
            Start-Sleep -Seconds 1
        }
        
        $this.RenderFullScreen()
    }
    
    [void] HandleRemoveAlias() {
        $repos = $this.RepoManager.GetRepositories()
        $selectedRepo = $repos[$this.SelectedIndex]
        
        if ($this.RepoManager.RemoveAlias($selectedRepo)) {
            $this.Console.ClearScreen()
            $this.Renderer.RenderSuccess("Alias removed successfully!")
            Start-Sleep -Seconds 1
        } else {
            $this.Console.ClearScreen()
            $this.Renderer.RenderWarning("No alias to remove for this repository.")
            Start-Sleep -Seconds 1
        }
        
        $this.RenderFullScreen()
    }
    
    [void] HandleInstallDependencies() {
        $repos = $this.RepoManager.GetRepositories()
        $selectedRepo = $repos[$this.SelectedIndex]
        
        # Call helper function that handles everything (UI + npm install)
        # This must be outside the class to show npm output properly
        $success = Invoke-NpmInstall -Repository $selectedRepo
        
        $this.RenderFullScreen()
    }
    
    [void] HandleRemoveNodeModules() {
        $repos = $this.RepoManager.GetRepositories()
        $selectedRepo = $repos[$this.SelectedIndex]
        
        if (-not $selectedRepo.HasNodeModules) {
            $this.Console.ClearScreen()
            $this.Renderer.RenderWarning("No node_modules folder found in this repository.")
            Start-Sleep -Seconds 2
            $this.RenderFullScreen()
            return
        }
        
        $this.Console.ClearScreen()
        $this.Renderer.RenderHeader("REMOVE NODE_MODULES")
        Write-Host "Repository: " -NoNewline -ForegroundColor Yellow
        Write-Host $selectedRepo.Name -ForegroundColor White
        Write-Host ("=" * 55) -ForegroundColor Cyan
        Write-Host ""
        Write-Host "This will delete the node_modules folder." -ForegroundColor Yellow
        Write-Host "Continue? (Y/n): " -NoNewline -ForegroundColor Gray
        
        $this.Console.ShowCursor()
        $confirm = Read-Host
        
        if ($confirm -eq '' -or $confirm -eq 'Y' -or $confirm -eq 'y') {
            # Ask about package-lock
            $npmService = $this.RepoManager.NpmService
            $hasPackageLock = $npmService.HasPackageLock($selectedRepo.FullPath)
            $removePackageLock = $false
            
            if ($hasPackageLock) {
                Write-Host ""
                Write-Host "Do you also want to remove package-lock.json? (y/N): " -NoNewline -ForegroundColor Cyan
                $packageLockConfirm = Read-Host
                $removePackageLock = ($packageLockConfirm -eq 'y' -or $packageLockConfirm -eq 'Y')
            }
            
            if ($this.RepoManager.RemoveNodeModules($selectedRepo, $removePackageLock)) {
                Start-Sleep -Seconds 2
            } else {
                Start-Sleep -Seconds 3
            }
        } else {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
        
        $this.Console.HideCursor()
        $this.RenderFullScreen()
    }
    
    [void] HandleCloneRepository() {
        $this.Console.ClearScreen()
        $this.Renderer.RenderHeader("CLONE REPOSITORY")
        Write-Host ""
        Write-Host "Enter the GitHub HTTPS URL:" -ForegroundColor Gray
        Write-Host "Example: https://github.com/user/repo.git" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "URL: " -NoNewline -ForegroundColor Yellow
        
        $this.Console.ShowCursor()
        $url = Read-Host
        $this.Console.HideCursor()
        
        if ([string]::IsNullOrWhiteSpace($url)) {
            Write-Host ""
            $this.Renderer.RenderWarning("Operation cancelled (empty URL).")
            Start-Sleep -Seconds 1
            $this.RenderFullScreen()
            return
        }
        
        Write-Host ""
        Write-Host "Cloning repository..." -ForegroundColor Yellow
        Write-Host ""
        
        $this.Console.ShowCursor()
        
        if ($this.RepoManager.CloneRepository($url, $this.BasePath)) {
            Write-Host ""
            $this.Renderer.RenderSuccess("Repository cloned successfully!")
            Start-Sleep -Seconds 2
        } else {
            Write-Host ""
            $this.Renderer.RenderError("Error cloning repository")
            Start-Sleep -Seconds 3
        }
        
        $this.Console.HideCursor()
        $this.RenderFullScreen()
    }
    
    [void] HandleDeleteRepository() {
        $repos = $this.RepoManager.GetRepositories()
        $selectedRepo = $repos[$this.SelectedIndex]
        
        $this.Console.ClearScreen()
        $this.Renderer.RenderHeader("DELETE REPOSITORY")
        Write-Host "Repository: " -NoNewline -ForegroundColor Red
        Write-Host $selectedRepo.Name -ForegroundColor White
        Write-Host ("=" * 55) -ForegroundColor Cyan
        Write-Host ""
        Write-Host "WARNING: This action is PERMANENT and cannot be undone!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Are you sure you want to delete this repository? (yes/no): " -NoNewline -ForegroundColor Yellow
        
        $this.Console.ShowCursor()
        $firstConfirm = Read-Host
        
        if ($firstConfirm -ne 'yes') {
            Write-Host ""
            $this.Renderer.RenderWarning("Operation cancelled.")
            Start-Sleep -Seconds 1
            $this.Console.HideCursor()
            $this.RenderFullScreen()
            return
        }
        
        # Load git status if not loaded
        if (-not $selectedRepo.HasGitStatusLoaded()) {
            $this.RepoManager.LoadGitStatus($selectedRepo)
        }
        
        # Check git status
        if ($selectedRepo.GitStatus -and $selectedRepo.GitStatus.IsGitRepo) {
            Write-Host ""
            Write-Host "Git repository detected:" -ForegroundColor Cyan
            Write-Host "  Current branch: " -NoNewline -ForegroundColor Gray
            Write-Host $selectedRepo.GitStatus.CurrentBranch -ForegroundColor White
            
            if ($selectedRepo.GitStatus.HasUncommittedChanges) {
                Write-Host "  - Has UNCOMMITTED changes" -ForegroundColor Red
            }
            
            if ($selectedRepo.GitStatus.HasUnpushedCommits) {
                Write-Host "  - Has UNPUSHED commits" -ForegroundColor Red
            }
            
            if ($selectedRepo.GitStatus.NeedsAttention()) {
                Write-Host ""
                Write-Host "There are uncommitted or unpushed changes!" -ForegroundColor Red
                Write-Host "Do you STILL want to delete? (type 'DELETE' to confirm): " -NoNewline -ForegroundColor Yellow
                $finalConfirm = Read-Host
                
                if ($finalConfirm -ne 'DELETE') {
                    Write-Host ""
                    $this.Renderer.RenderWarning("Operation cancelled.")
                    Start-Sleep -Seconds 1
                    $this.Console.HideCursor()
                    $this.RenderFullScreen()
                    return
                }
            }
        }
        
        # Final confirmation
        Write-Host ""
        Write-Host "Type the repository name to confirm deletion: " -NoNewline -ForegroundColor Yellow
        $nameConfirm = Read-Host
        
        if ($nameConfirm -ne $selectedRepo.Name) {
            Write-Host ""
            $this.Renderer.RenderWarning("Name doesn't match. Operation cancelled.")
            Start-Sleep -Seconds 2
            $this.Console.HideCursor()
            $this.RenderFullScreen()
            return
        }
        
        # Delete
        Write-Host ""
        Write-Host "Deleting repository..." -ForegroundColor Red
        
        if ($this.RepoManager.DeleteRepository($selectedRepo, $true)) {
            $this.Renderer.RenderSuccess("Repository deleted successfully!")
            Start-Sleep -Seconds 2
            
            # Check if there are still repos
            $remainingRepos = $this.RepoManager.GetRepositories()
            if ($remainingRepos.Count -eq 0) {
                $this.Console.ClearScreen()
                $this.Renderer.RenderWarning("No more repositories found.")
                $this.Running = $false
                return
            }
            
            # Adjust selected index
            if ($this.SelectedIndex -ge $remainingRepos.Count) {
                $this.SelectedIndex = $remainingRepos.Count - 1
            }
        } else {
            $this.Renderer.RenderError("Error deleting repository")
            Start-Sleep -Seconds 3
        }
        
        $this.Console.HideCursor()
        $this.RenderFullScreen()
    }
    
    [void] HandleLoadGitStatusCurrent() {
        $repos = $this.RepoManager.GetRepositories()
        $selectedRepo = $repos[$this.SelectedIndex]
        
        # Update footer to show loading
        $footerLine = [Constants]::CursorStartLine + $repos.Count + 1
        $this.Console.SetCursorPosition(0, $footerLine)
        Write-Host ("=" * 55) -ForegroundColor Cyan
        Write-Host "Loading git information for $($selectedRepo.Name)..." -ForegroundColor Yellow
        
        # Load
        $this.RepoManager.LoadGitStatus($selectedRepo)
        
        # Update display
        $this.UpdateSelection($this.SelectedIndex)
    }
    
    [void] HandleLoadGitStatusAll() {
        $repos = $this.RepoManager.GetRepositories()
        $loadedCount = $this.RepoManager.GetLoadedGitStatusCount()
        
        # Check if all loaded
        if ($loadedCount -eq $repos.Count) {
            $footerLine = [Constants]::CursorStartLine + $repos.Count + 1
            $this.Console.SetCursorPosition(0, $footerLine)
            Write-Host ("=" * 55) -ForegroundColor Cyan
            Write-Host "All repositories already loaded! (use L to refresh current)" -ForegroundColor Green
            Start-Sleep -Milliseconds 1500
            $this.UpdateFooter()
            return
        }
        
        # Update footer to show loading
        $footerLine = [Constants]::CursorStartLine + $repos.Count + 1
        $needsLoading = $repos.Count - $loadedCount
        
        $this.Console.SetCursorPosition(0, $footerLine)
        Write-Host ("=" * 55) -ForegroundColor Cyan
        Write-Host "Loading git info for $needsLoading repositories..." -ForegroundColor Yellow
        
        # Load missing
        $this.RepoManager.LoadMissingGitStatus()
        
        # Full redraw
        $this.RenderFullScreen()
    }
    
    [void] HandleQuit() {
        $this.Console.ClearScreen()
        $this.Renderer.RenderWarning("Navigation cancelled.")
        $this.Running = $false
    }
}
