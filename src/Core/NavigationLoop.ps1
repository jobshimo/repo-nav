<#
.SYNOPSIS
    Main navigation loop - outside classes to avoid PowerShell command output issues
#>

function Start-NavigationLoop {
    param(
        [Parameter(Mandatory = $true)]
        $RepoManager,
        
        [Parameter(Mandatory = $true)]
        $Renderer,
        
        [Parameter(Mandatory = $true)]
        $Console,
        
        [Parameter(Mandatory = $true)]
        $ColorSelector,
        
        [Parameter(Mandatory = $true)]
        [string]$BasePath
    )
    
    # Load repositories
    $RepoManager.LoadRepositories($BasePath)
    
    $repos = $RepoManager.GetRepositories()
    if ($repos.Count -eq 0) {
        $Renderer.RenderError("No repositories found in this folder.")
        return
    }
    
    $SelectedIndex = 0
    $Running = $true
    
    try {
        $Console.HideCursor()
        
        # Initial full render
        $Console.ClearScreen()
        $Renderer.RenderHeader("REPOSITORY NAVIGATOR")
        $Renderer.RenderMenu()
        
        for ($i = 0; $i -lt $repos.Count; $i++) {
            $Renderer.RenderRepositoryItem($repos[$i], ($i -eq $SelectedIndex))
        }
        
        Write-Host ""
        $totalRepos = $repos.Count
        $loadedRepos = $repos | Where-Object { $_.HasGitStatusLoaded() } | Measure-Object | Select-Object -ExpandProperty Count
        $Renderer.RenderGitStatusFooter($repos[$SelectedIndex], $totalRepos, $loadedRepos)
        
        $previousIndex = $SelectedIndex
        
        # Main input loop - OUTSIDE CLASS
        while ($Running) {
            $key = $Console.ReadKey()
            
            switch ($key.VirtualKeyCode) {
                ([Constants]::KEY_UP_ARROW) {
                    $previousIndex = $SelectedIndex
                    if ($SelectedIndex -gt 0) {
                        $SelectedIndex--
                    } else {
                        $SelectedIndex = $repos.Count - 1
                    }
                    
                    # Update display
                    $startLine = [Constants]::CursorStartLine
                    $Renderer.UpdateRepositoryItemAt(($startLine + $previousIndex), $repos[$previousIndex], $false)
                    $Renderer.UpdateRepositoryItemAt(($startLine + $SelectedIndex), $repos[$SelectedIndex], $true)
                    
                    $footerLine = $startLine + $repos.Count + 1
                    $Console.SetCursorPosition(0, $footerLine)
                    $Renderer.ClearGitStatusFooter($footerLine)
                    $Renderer.RenderGitStatusFooter($repos[$SelectedIndex], $totalRepos, $loadedRepos)
                }
                
                ([Constants]::KEY_DOWN_ARROW) {
                    $previousIndex = $SelectedIndex
                    if ($SelectedIndex -lt ($repos.Count - 1)) {
                        $SelectedIndex++
                    } else {
                        $SelectedIndex = 0
                    }
                    
                    # Update display
                    $startLine = [Constants]::CursorStartLine
                    $Renderer.UpdateRepositoryItemAt(($startLine + $previousIndex), $repos[$previousIndex], $false)
                    $Renderer.UpdateRepositoryItemAt(($startLine + $SelectedIndex), $repos[$SelectedIndex], $true)
                    
                    $footerLine = $startLine + $repos.Count + 1
                    $Console.SetCursorPosition(0, $footerLine)
                    $Renderer.ClearGitStatusFooter($footerLine)
                    $Renderer.RenderGitStatusFooter($repos[$SelectedIndex], $totalRepos, $loadedRepos)
                }
                
                ([Constants]::KEY_ENTER) {
                    $selectedRepo = $repos[$SelectedIndex]
                    $Console.ClearScreen()
                    $Renderer.RenderSuccess("Opening: $($selectedRepo.Name)")
                    Set-Location $selectedRepo.FullPath
                    $Running = $false
                }
                
                ([Constants]::KEY_E) {
                    # Edit alias
                    $selectedRepo = $repos[$SelectedIndex]
                    if (Invoke-AliasEdit -RepoManager $RepoManager -Repository $selectedRepo -ColorSelector $ColorSelector) {
                        # Refresh and redraw
                        $RepoManager.LoadRepositories($BasePath)
                        $repos = $RepoManager.GetRepositories()
                    }
                    
                    $Console.ClearScreen()
                    $Renderer.RenderHeader("REPOSITORY NAVIGATOR")
                    $Renderer.RenderMenu()
                    
                    for ($i = 0; $i -lt $repos.Count; $i++) {
                        $Renderer.RenderRepositoryItem($repos[$i], ($i -eq $SelectedIndex))
                    }
                    
                    Write-Host ""
                    $totalRepos = $repos.Count
                    $loadedRepos = $repos | Where-Object { $_.HasGitStatusLoaded() } | Measure-Object | Select-Object -ExpandProperty Count
                    $Renderer.RenderGitStatusFooter($repos[$SelectedIndex], $totalRepos, $loadedRepos)
                    $Console.HideCursor()
                }
                
                ([Constants]::KEY_R) {
                    # Remove alias
                    $selectedRepo = $repos[$SelectedIndex]
                    if (Invoke-AliasRemove -RepoManager $RepoManager -Repository $selectedRepo) {
                        # Refresh and redraw
                        $RepoManager.LoadRepositories($BasePath)
                        $repos = $RepoManager.GetRepositories()
                    }
                    
                    $Console.ClearScreen()
                    $Renderer.RenderHeader("REPOSITORY NAVIGATOR")
                    $Renderer.RenderMenu()
                    
                    for ($i = 0; $i -lt $repos.Count; $i++) {
                        $Renderer.RenderRepositoryItem($repos[$i], ($i -eq $SelectedIndex))
                    }
                    
                    Write-Host ""
                    $totalRepos = $repos.Count
                    $loadedRepos = $repos | Where-Object { $_.HasGitStatusLoaded() } | Measure-Object | Select-Object -ExpandProperty Count
                    $Renderer.RenderGitStatusFooter($repos[$SelectedIndex], $totalRepos, $loadedRepos)
                    $Console.HideCursor()
                }
                
                ([Constants]::KEY_I) {
                    # Call helper function directly - OUTSIDE CLASS
                    $selectedRepo = $repos[$SelectedIndex]
                    Invoke-NpmInstall -Repository $selectedRepo
                    
                    # Refresh and redraw
                    $repos = $RepoManager.GetRepositories()
                    $Console.ClearScreen()
                    $Renderer.RenderHeader("REPOSITORY NAVIGATOR")
                    $Renderer.RenderMenu()
                    
                    for ($i = 0; $i -lt $repos.Count; $i++) {
                        $Renderer.RenderRepositoryItem($repos[$i], ($i -eq $SelectedIndex))
                    }
                    
                    Write-Host ""
                    $loadedRepos = $repos | Where-Object { $_.HasGitStatusLoaded() } | Measure-Object | Select-Object -ExpandProperty Count
                    $Renderer.RenderGitStatusFooter($repos[$SelectedIndex], $totalRepos, $loadedRepos)
                    $Console.HideCursor()
                }
                
                ([Constants]::KEY_X) {
                    # Remove node_modules
                    $selectedRepo = $repos[$SelectedIndex]
                    if (Invoke-NodeModulesRemove -RepoManager $RepoManager -Repository $selectedRepo) {
                        # Refresh and redraw
                        $RepoManager.LoadRepositories($BasePath)
                        $repos = $RepoManager.GetRepositories()
                    }
                    
                    $Console.ClearScreen()
                    $Renderer.RenderHeader("REPOSITORY NAVIGATOR")
                    $Renderer.RenderMenu()
                    
                    for ($i = 0; $i -lt $repos.Count; $i++) {
                        $Renderer.RenderRepositoryItem($repos[$i], ($i -eq $SelectedIndex))
                    }
                    
                    Write-Host ""
                    $totalRepos = $repos.Count
                    $loadedRepos = $repos | Where-Object { $_.HasGitStatusLoaded() } | Measure-Object | Select-Object -ExpandProperty Count
                    $Renderer.RenderGitStatusFooter($repos[$SelectedIndex], $totalRepos, $loadedRepos)
                    $Console.HideCursor()
                }
                
                ([Constants]::KEY_C) {
                    # Clone repository
                    if (Invoke-RepositoryClone -RepoManager $RepoManager -BasePath $BasePath) {
                        # Refresh and redraw
                        $RepoManager.LoadRepositories($BasePath)
                        $repos = $RepoManager.GetRepositories()
                    }
                    
                    if ($repos.Count -eq 0) {
                        $Console.ClearScreen()
                        $Renderer.RenderWarning("No repositories found.")
                        $Running = $false
                    } else {
                        # Adjust index if needed
                        if ($SelectedIndex -ge $repos.Count) {
                            $SelectedIndex = $repos.Count - 1
                        }
                        
                        $Console.ClearScreen()
                        $Renderer.RenderHeader("REPOSITORY NAVIGATOR")
                        $Renderer.RenderMenu()
                        
                        for ($i = 0; $i -lt $repos.Count; $i++) {
                            $Renderer.RenderRepositoryItem($repos[$i], ($i -eq $SelectedIndex))
                        }
                        
                        Write-Host ""
                        $totalRepos = $repos.Count
                        $loadedRepos = $repos | Where-Object { $_.HasGitStatusLoaded() } | Measure-Object | Select-Object -ExpandProperty Count
                        $Renderer.RenderGitStatusFooter($repos[$SelectedIndex], $totalRepos, $loadedRepos)
                        $Console.HideCursor()
                    }
                }
                
                ([Constants]::KEY_DELETE) {
                    # Delete repository
                    $selectedRepo = $repos[$SelectedIndex]
                    $deleted = Invoke-RepositoryDelete -RepoManager $RepoManager -Repository $selectedRepo
                    
                    if ($deleted) {
                        # Refresh and redraw
                        $RepoManager.LoadRepositories($BasePath)
                        $repos = $RepoManager.GetRepositories()
                        
                        if ($repos.Count -eq 0) {
                            $Console.ClearScreen()
                            $Renderer.RenderWarning("No more repositories found.")
                            $Running = $false
                        } else {
                            # Adjust index if needed
                            if ($SelectedIndex -ge $repos.Count) {
                                $SelectedIndex = $repos.Count - 1
                            }
                            
                            $Console.ClearScreen()
                            $Renderer.RenderHeader("REPOSITORY NAVIGATOR")
                            $Renderer.RenderMenu()
                            
                            for ($i = 0; $i -lt $repos.Count; $i++) {
                                $Renderer.RenderRepositoryItem($repos[$i], ($i -eq $SelectedIndex))
                            }
                            
                            Write-Host ""
                            $totalRepos = $repos.Count
                            $loadedRepos = $repos | Where-Object { $_.HasGitStatusLoaded() } | Measure-Object | Select-Object -ExpandProperty Count
                            $Renderer.RenderGitStatusFooter($repos[$SelectedIndex], $totalRepos, $loadedRepos)
                            $Console.HideCursor()
                        }
                    } else {
                        # Redraw if deletion was cancelled
                        $Console.ClearScreen()
                        $Renderer.RenderHeader("REPOSITORY NAVIGATOR")
                        $Renderer.RenderMenu()
                        
                        for ($i = 0; $i -lt $repos.Count; $i++) {
                            $Renderer.RenderRepositoryItem($repos[$i], ($i -eq $SelectedIndex))
                        }
                        
                        Write-Host ""
                        $Renderer.RenderGitStatusFooter($repos[$SelectedIndex], $totalRepos, $loadedRepos)
                        $Console.HideCursor()
                    }
                }
                
                ([Constants]::KEY_L) {
                    # Load git status for current repository
                    $selectedRepo = $repos[$SelectedIndex]
                    $RepoManager.LoadGitStatus($selectedRepo)
                    
                    # Update display
                    $startLine = [Constants]::CursorStartLine
                    $Renderer.UpdateRepositoryItemAt(($startLine + $SelectedIndex), $repos[$SelectedIndex], $true)
                    
                    $footerLine = $startLine + $repos.Count + 1
                    $Console.SetCursorPosition(0, $footerLine)
                    $totalRepos = $repos.Count
                    $loadedRepos = $repos | Where-Object { $_.HasGitStatusLoaded() } | Measure-Object | Select-Object -ExpandProperty Count
                    $Renderer.ClearGitStatusFooter($footerLine)
                    $Renderer.RenderGitStatusFooter($repos[$SelectedIndex], $totalRepos, $loadedRepos)
                }
                
                ([Constants]::KEY_G) {
                    # Load git status for all repositories
                    $RepoManager.LoadMissingGitStatus()
                    
                    # Full redraw
                    $Console.ClearScreen()
                    $Renderer.RenderHeader("REPOSITORY NAVIGATOR")
                    $Renderer.RenderMenu()
                    
                    for ($i = 0; $i -lt $repos.Count; $i++) {
                        $Renderer.RenderRepositoryItem($repos[$i], ($i -eq $SelectedIndex))
                    }
                    
                    Write-Host ""
                    $totalRepos = $repos.Count
                    $loadedRepos = $repos | Where-Object { $_.HasGitStatusLoaded() } | Measure-Object | Select-Object -ExpandProperty Count
                    $Renderer.RenderGitStatusFooter($repos[$SelectedIndex], $totalRepos, $loadedRepos)
                }
                
                ([Constants]::KEY_F) {
                    # Toggle favorite status
                    $selectedRepo = $repos[$SelectedIndex]
                    $RepoManager.ToggleFavorite($selectedRepo)
                    
                    # Refresh repositories list (re-sorted)
                    $repos = $RepoManager.GetRepositories()
                    
                    # Find new index of current repo (it may have moved)
                    $newIndex = 0
                    for ($i = 0; $i -lt $repos.Count; $i++) {
                        if ($repos[$i].Name -eq $selectedRepo.Name) {
                            $newIndex = $i
                            break
                        }
                    }
                    $SelectedIndex = $newIndex
                    
                    # Full redraw
                    $Console.ClearScreen()
                    $Renderer.RenderHeader("REPOSITORY NAVIGATOR")
                    $Renderer.RenderMenu()
                    
                    for ($i = 0; $i -lt $repos.Count; $i++) {
                        $Renderer.RenderRepositoryItem($repos[$i], ($i -eq $SelectedIndex))
                    }
                    
                    Write-Host ""
                    $totalRepos = $repos.Count
                    $loadedRepos = $repos | Where-Object { $_.HasGitStatusLoaded() } | Measure-Object | Select-Object -ExpandProperty Count
                    $Renderer.RenderGitStatusFooter($repos[$SelectedIndex], $totalRepos, $loadedRepos)
                    $Console.HideCursor()
                }
                
                ([Constants]::KEY_Q) {
                    $Console.ClearScreen()
                    $Renderer.RenderWarning("Navigation cancelled.")
                    $Running = $false
                }
                
                ([Constants]::KEY_ESC) {
                    $Console.ClearScreen()
                    $Renderer.RenderWarning("Navigation cancelled.")
                    $Running = $false
                }
            }
        }
    }
    finally {
        $Console.ShowCursor()
    }
}
