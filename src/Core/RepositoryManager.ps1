<#
.SYNOPSIS
    RepositoryManager - Coordinates all repository operations
    
.DESCRIPTION
    Following SOLID principles:
    - SRP: Only manages repository operations coordination
    - OCP: Open for extension (new operations), closed for modification
    - DIP: Depends on service abstractions (GitService, NpmService, AliasManager)
    - Composition over Inheritance: Uses services through composition
    
    This is the "Facade" that provides high-level operations:
    - Loading and initializing repositories
    - Setting/removing aliases
    - Managing favorites
    - Git operations (load status, clone)
    - Npm operations (install, remove)
    - Repository deletion
#>

class RepositoryManager {
    # Dependencies (injected)
    [GitService] $GitService
    [NpmService] $NpmService
    [AliasManager] $AliasManager
    [ConfigurationService] $ConfigService
    [UserPreferencesService] $PreferencesService
    
    # Cache for loaded repositories
    [System.Collections.ArrayList] $Repositories
    
    # Constructor with dependency injection
    RepositoryManager(
        [GitService]$gitService,
        [NpmService]$npmService,
        [AliasManager]$aliasManager,
        [ConfigurationService]$configService,
        [UserPreferencesService]$preferencesService
    ) {
        $this.GitService = $gitService
        $this.NpmService = $npmService
        $this.AliasManager = $aliasManager
        $this.ConfigService = $configService
        $this.PreferencesService = $preferencesService
        $this.Repositories = [System.Collections.ArrayList]::new()
    }
    
    # Load all repositories from base path
    [void] LoadRepositories([string]$basePath) {
        $this.Repositories.Clear()
        
        # Get all directories except 'envs', 'classes', and 'repo-nav'
        $directories = Get-ChildItem -Directory -Path $basePath | 
                       Where-Object { $_.Name -notin @('envs', 'classes', 'repo-nav') }
        
        if ($directories.Count -eq 0) {
            return
        }
        
        # Get aliases and favorites
        $aliases = $this.AliasManager.GetAllAliases()
        $favorites = $this.AliasManager.GetFavorites()
        
        # Create repository models
        foreach ($dir in $directories) {
            $repo = [RepositoryModel]::new($dir)
            
            # Set alias if exists
            if ($aliases.ContainsKey($repo.Name)) {
                $repo.SetAlias($aliases[$repo.Name])
            }
            
            # Set favorite status
            if ($favorites -contains $repo.Name) {
                $repo.MarkAsFavorite($true)
            }
            
            # Check node_modules
            $this.NpmService.UpdateRepositoryModel($repo)
            
            $this.Repositories.Add($repo) | Out-Null
        }
        
        # Get user preference for favorites position
        [bool]$favoritesOnTop = $this.PreferencesService.GetPreference("display", "favoritesOnTop")
        
        # Sort based on user preference
        if ($favoritesOnTop) {
            # Favorites first, then alphabetically
            $sorted = $this.Repositories | Sort-Object @{Expression = {-$_.IsFavorite}}, Name
        } else {
            # Just alphabetically (favorites stay in their position)
            $sorted = $this.Repositories | Sort-Object Name
        }
        
        $this.Repositories.Clear()
        $this.Repositories.AddRange($sorted)
    }
    
    # Get all loaded repositories
    [RepositoryModel[]] GetRepositories() {
        return $this.Repositories.ToArray()
    }
    
    # Get repository by name
    [RepositoryModel] GetRepository([string]$name) {
        foreach ($repo in $this.Repositories) {
            if ($repo.Name -eq $name) {
                return $repo
            }
        }
        return $null
    }
    
    # Load git status for a specific repository
    [void] LoadGitStatus([RepositoryModel]$repository) {
        $gitStatus = $this.GitService.GetGitStatus($repository)
        $repository.SetGitStatus($gitStatus)
    }
    
    # Load git status for all repositories
    [void] LoadAllGitStatus() {
        foreach ($repo in $this.Repositories) {
            $this.LoadGitStatus($repo)
        }
    }
    
    # Load git status only for repositories that don't have it
    # Accepts optional progress callback: { param($current, $total) }
    [void] LoadMissingGitStatus([scriptblock]$progressCallback = $null) {
        $missingRepos = $this.Repositories | Where-Object { -not $_.HasGitStatusLoaded() }
        $total = $missingRepos.Count
        
        if ($total -eq 0) { return }
        
        # Show progress immediately
        if ($null -ne $progressCallback) {
            & $progressCallback 0 $total
        }
        
        # Parallel execution using background jobs for better performance
        $jobs = [System.Collections.Generic.List[hashtable]]::new()
        
        # Start all git status jobs in parallel
        foreach ($repo in $missingRepos) {
            $job = Start-Job -ScriptBlock {
                param($repoPath)
                
                # Execute git commands
                Push-Location $repoPath
                try {
                    $isGitRepo = Test-Path ".git"
                    if (-not $isGitRepo) {
                        return @{
                            RepoPath = $repoPath
                            IsGitRepo = $false
                            CurrentBranch = ""
                            HasUncommittedChanges = $false
                            HasUnpushedCommits = $false
                        }
                    }
                    
                    $branch = git rev-parse --abbrev-ref HEAD 2>$null
                    $hasChanges = (git status --porcelain 2>$null).Length -gt 0
                    
                    # Check unpushed commits
                    $hasUnpushed = $false
                    $upstream = git rev-parse --abbrev-ref "@{u}" 2>$null
                    if ($LASTEXITCODE -eq 0 -and $upstream) {
                        $unpushedCount = git rev-list --count "@{u}..HEAD" 2>$null
                        $hasUnpushed = ($LASTEXITCODE -eq 0 -and [int]$unpushedCount -gt 0)
                    }
                    
                    return @{
                        RepoPath = $repoPath
                        IsGitRepo = $true
                        CurrentBranch = $branch
                        HasUncommittedChanges = $hasChanges
                        HasUnpushedCommits = $hasUnpushed
                    }
                }
                finally {
                    Pop-Location
                }
            } -ArgumentList $repo.FullPath
            
            $jobs.Add(@{
                Job = $job
                Repository = $repo
                Processed = $false
            })
        }
        
        # Wait for jobs to complete and update progress
        $completed = 0
        $maxWaitSeconds = 30
        $startTime = Get-Date
        
        while ($completed -lt $total) {
            # Check timeout
            if (((Get-Date) - $startTime).TotalSeconds -gt $maxWaitSeconds) {
                # Timeout - stop remaining jobs
                foreach ($jobInfo in $jobs) {
                    if (-not $jobInfo.Processed) {
                        Stop-Job -Job $jobInfo.Job -ErrorAction SilentlyContinue
                        Remove-Job -Job $jobInfo.Job -Force -ErrorAction SilentlyContinue
                    }
                }
                break
            }
            
            # Process completed jobs
            foreach ($jobInfo in $jobs) {
                if (-not $jobInfo.Processed -and $jobInfo.Job.State -eq 'Completed') {
                    $result = Receive-Job -Job $jobInfo.Job
                    Remove-Job -Job $jobInfo.Job -Force
                    
                    # Verify we got the correct repo by matching path
                    if ($result.RepoPath -eq $jobInfo.Repository.FullPath) {
                        # Create GitStatusModel and update the SPECIFIC repository
                        $gitStatus = [GitStatusModel]::new(
                            $result.IsGitRepo,
                            $result.CurrentBranch,
                            $result.HasUncommittedChanges,
                            $result.HasUnpushedCommits
                        )
                        $jobInfo.Repository.SetGitStatus($gitStatus)
                    }
                    
                    $jobInfo.Processed = $true
                    $completed++
                    
                    # Invoke progress callback
                    if ($null -ne $progressCallback) {
                        & $progressCallback $completed $total
                    }
                }
            }
            
            # Small delay to avoid CPU spinning (reduced to 10ms for faster updates)
            if ($completed -lt $total) {
                Start-Sleep -Milliseconds 10
            }
        }
        
        # Clean up any remaining jobs
        foreach ($jobInfo in $jobs) {
            if (-not $jobInfo.Processed) {
                Stop-Job -Job $jobInfo.Job -ErrorAction SilentlyContinue
                Remove-Job -Job $jobInfo.Job -Force -ErrorAction SilentlyContinue
            }
        }
    }
    
    # Count how many repos have git status loaded
    [int] GetLoadedGitStatusCount() {
        $count = 0
        foreach ($repo in $this.Repositories) {
            if ($repo.HasGitStatusLoaded()) {
                $count++
            }
        }
        return $count
    }
    
    # Set alias for a repository
    [bool] SetAlias([RepositoryModel]$repository, [AliasInfo]$aliasInfo) {
        if ($this.AliasManager.SetAlias($repository.Name, $aliasInfo)) {
            $repository.SetAlias($aliasInfo)
            return $true
        }
        return $false
    }
    
    # Remove alias from a repository
    [bool] RemoveAlias([RepositoryModel]$repository) {
        if ($this.AliasManager.RemoveAlias($repository.Name)) {
            $repository.RemoveAlias()
            return $true
        }
        return $false
    }
    
    # Toggle favorite status
    [bool] ToggleFavorite([RepositoryModel]$repository) {
        $result = $this.AliasManager.ToggleFavorite($repository.Name)
        if ($result) {
            $repository.MarkAsFavorite(-not $repository.IsFavorite)
        }
        return $result
    }
    
    # Install npm dependencies
    [bool] InstallDependencies([RepositoryModel]$repository) {
        $result = $this.NpmService.InstallDependencies($repository.FullPath)
        if ($result) {
            # Update repository model
            $this.NpmService.UpdateRepositoryModel($repository)
        }
        return $result
    }
    
    # Remove node_modules
    [bool] RemoveNodeModules([RepositoryModel]$repository, [bool]$removePackageLock = $false) {
        $result = $this.NpmService.RemoveNodeModules($repository.FullPath, $removePackageLock)
        if ($result) {
            # Update repository model
            $this.NpmService.UpdateRepositoryModel($repository)
        }
        return $result
    }
    
    # Clone a repository
    [bool] CloneRepository([string]$url, [string]$basePath) {
        # Validate URL
        if (-not $this.GitService.IsValidGitUrl($url)) {
            Write-Error "Invalid Git URL format"
            return $false
        }
        
        # Get repo name
        $repoName = $this.GitService.GetRepoNameFromUrl($url)
        if ([string]::IsNullOrWhiteSpace($repoName)) {
            Write-Error "Could not extract repository name from URL"
            return $false
        }
        
        # Check if already exists
        $targetPath = Join-Path $basePath $repoName
        if (Test-Path $targetPath) {
            Write-Error "Repository '$repoName' already exists"
            return $false
        }
        
        # Clone
        $result = $this.GitService.CloneRepository($url, $basePath)
        
        if ($result) {
            # Reload repositories to include the new one
            $this.LoadRepositories($basePath)
        }
        
        return $result
    }
    
    # Delete a repository (with safety checks)
    [bool] DeleteRepository([RepositoryModel]$repository, [bool]$force = $false) {
        # Safety check: Load git status if not loaded
        if (-not $repository.HasGitStatusLoaded()) {
            $this.LoadGitStatus($repository)
        }
        
        # Check for uncommitted changes or unpushed commits
        if (-not $force -and $repository.GitStatus -and $repository.GitStatus.NeedsAttention()) {
            Write-Warning "Repository has uncommitted changes or unpushed commits. Use -force to delete anyway."
            return $false
        }
        
        try {
            Remove-Item -Path $repository.FullPath -Recurse -Force -ErrorAction Stop
            
            # Remove from collection
            $this.Repositories.Remove($repository)
            
            return $true
        }
        catch {
            Write-Error "Error deleting repository: $_"
            return $false
        }
    }
    
    # Refresh a specific repository (reload from disk)
    [void] RefreshRepository([RepositoryModel]$repository) {
        # Update npm status
        $this.NpmService.UpdateRepositoryModel($repository)
        
        # Reload git status
        if ($repository.HasGitStatusLoaded()) {
            $this.LoadGitStatus($repository)
        }
    }
}
