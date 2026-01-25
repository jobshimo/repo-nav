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
    
    # Clone a new repository
    # Returns a result object { Success: bool, Message: string }
    [hashtable] CloneRepository([string]$url, [string]$customName, [string]$basePath) {
        if (-not $this.GitService.IsValidGitUrl($url)) {
            return @{ Success = $false; Message = "Invalid Git URL" }
        }

        # Determine folder name
        $repoName = if (-not [string]::IsNullOrWhiteSpace($customName)) { 
            $customName 
        } else { 
            $this.GitService.GetRepoNameFromUrl($url) 
        }
        
        if ([string]::IsNullOrWhiteSpace($repoName)) {
             return @{ Success = $false; Message = "Could not determine repository name" }
        }

        $targetPath = Join-Path $basePath $repoName
        
        if (Test-Path $targetPath) {
            return @{ Success = $false; Message = "Folder '$repoName' already exists" }
        }
        
        $success = $this.GitService.CloneRepository($url, $targetPath)
        
        if ($success) {
            return @{ Success = $true; Message = "Repository cloned successfully" }
        } else {
            return @{ Success = $false; Message = "Git clone failed" }
        }
    }

    # Delete a repository
    # Returns a result object { Success: bool, Message: string }
    [hashtable] DeleteRepository([RepositoryModel]$repository) {
        if (-not (Test-Path $repository.FullPath)) {
             return @{ Success = $false; Message = "Repository path does not exist" }
        }

        try {
            Remove-Item -Path $repository.FullPath -Recurse -Force -ErrorAction Stop
            
            # Remove alias if exists
            if ($repository.HasAlias) {
                $this.RemoveAlias($repository)
            }
            
            # Remove from local list if it exists there (though LoadRepositories usually refreshes everything)
            if ($this.Repositories.Contains($repository)) {
                $this.Repositories.Remove($repository)
            }
            
            return @{ Success = $true; Message = "Repository deleted successfully" }
        }
        catch {
             return @{ Success = $false; Message = "Error deleting repository: $_" }
        }
    }

    # Load all repositories from base path
    [void] LoadRepositories([string]$basePath) {
        $oldRepos = @{}
        foreach ($repo in $this.Repositories) {
            $oldRepos[$repo.Name] = $repo
        }
        
        $this.Repositories.Clear()
        
        $directories = Get-ChildItem -Directory -Path $basePath | 
                       Where-Object { $_.Name -notin @('envs', 'classes', 'repo-nav') }
        
        if ($directories.Count -eq 0) {
            return
        }
        
        $aliases = $this.AliasManager.GetAllAliases()
        $favorites = $this.AliasManager.GetFavorites()
        
        foreach ($dir in $directories) {
            $repo = [RepositoryModel]::new($dir)
            
            if ($aliases.ContainsKey($repo.Name)) {
                $repo.SetAlias($aliases[$repo.Name])
            }
            
            if ($favorites -contains $repo.Name) {
                $repo.MarkAsFavorite($true)
            }
            
            $this.NpmService.UpdateRepositoryModel($repo)
            
            if ($oldRepos.ContainsKey($repo.Name) -and $oldRepos[$repo.Name].HasGitStatusLoaded()) {
                $repo.SetGitStatus($oldRepos[$repo.Name].GitStatus)
            }
            
            $this.Repositories.Add($repo) | Out-Null
        }
        
        # Get user preference for favorites position
        [bool]$favoritesOnTop = $this.PreferencesService.GetPreference("display", "favoritesOnTop")
        
        # Sort based on user preference
        if ($favoritesOnTop) {
            # Favorites first, then alphabetically
            $sorted = @($this.Repositories | Sort-Object @{Expression = {-$_.IsFavorite}}, Name)
        } else {
            # Just alphabetically (favorites stay in their position)
            $sorted = @($this.Repositories | Sort-Object Name)
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
        $this.LoadGitStatusForRepos($missingRepos, $progressCallback)
    }
    
    [void] LoadGitStatusForRepos([array]$repos, [scriptblock]$progressCallback = $null) {
        $total = $repos.Count
        
        if ($total -eq 0) { return }
        
        if ($null -ne $progressCallback) {
            & $progressCallback 0 $total
        }
        
        # Parallel execution using Runspaces (more reliable than Start-Job)
        $runspacePool = [runspacefactory]::CreateRunspacePool(1, [Environment]::ProcessorCount)
        $runspacePool.Open()
        
        $runspaces = [System.Collections.Generic.List[hashtable]]::new()
        
        $scriptBlock = {
            param([string]$repoPath)
            
            Set-StrictMode -Version Latest
            
            $local:isGitRepo = $false
            $local:branchResult = ""
            $local:hasChangesResult = $false
            $local:hasUnpushedResult = $false
            
            Push-Location $repoPath
            try {
                $local:isGitRepo = Test-Path ".git"
                if (-not $local:isGitRepo) {
                    return [PSCustomObject]@{
                        IsGitRepo = $false
                        CurrentBranch = ""
                        HasUncommittedChanges = $false
                        HasUnpushedCommits = $false
                    }
                }
                
                $local:branchOutput = git rev-parse --abbrev-ref HEAD 2>$null
                $local:branchResult = ($local:branchOutput | Out-String).Trim()
                
                $local:statusOutput = git status --porcelain 2>$null
                $local:statusStr = ($local:statusOutput | Out-String).Trim()
                $local:hasChangesResult = ($local:statusStr.Length -gt 0)
                
                $local:upstream = git rev-parse --abbrev-ref "@{u}" 2>$null
                $local:unpushedCount = git rev-list --count "@{u}..HEAD" 2>$null
                $local:countStr = ($local:unpushedCount | Out-String).Trim()
                $local:hasUnpushedResult = $false
                if ($local:countStr -match '^\d+$') {
                    $local:hasUnpushedResult = ([int]$local:countStr -gt 0)
                }
                
                return [PSCustomObject]@{
                    IsGitRepo = $local:isGitRepo
                    CurrentBranch = $local:branchResult
                    HasUncommittedChanges = $local:hasChangesResult
                    HasUnpushedCommits = $local:hasUnpushedResult
                }
            }
            finally {
                Pop-Location
            }
        }
        
        foreach ($repo in $repos) {
            $powershell = [powershell]::Create().AddScript($scriptBlock).AddArgument($repo.FullPath)
            $powershell.RunspacePool = $runspacePool
            
            $runspaces.Add(@{
                PowerShell = $powershell
                Handle = $powershell.BeginInvoke()
                Repository = $repo
            })
        }
        
        # Wait for completion and update progress
        $completed = 0
        $maxWaitSeconds = 30
        $startTime = Get-Date
        
        while ($completed -lt $total) {
            # Check timeout
            if (((Get-Date) - $startTime).TotalSeconds -gt $maxWaitSeconds) {
                break
            }
            
            foreach ($runspaceInfo in $runspaces) {
                if ($null -ne $runspaceInfo.Handle -and $runspaceInfo.Handle.IsCompleted) {
                    try {
                        $resultArray = $runspaceInfo.PowerShell.EndInvoke($runspaceInfo.Handle)
                        
                        if ($resultArray.Count -gt 0) {
                            $result = $resultArray[0]
                            
                            $gitStatus = [GitStatusModel]::new(
                                $result.IsGitRepo,
                                $result.HasUncommittedChanges,
                                $result.HasUnpushedCommits,
                                $result.CurrentBranch
                            )
                            $runspaceInfo.Repository.SetGitStatus($gitStatus)
                        }
                    }
                    catch {
                    }
                    finally {
                        $runspaceInfo.PowerShell.Dispose()
                        $runspaceInfo.Handle = $null
                    }
                    
                    $completed++
                    
                    if ($null -ne $progressCallback) {
                        & $progressCallback $completed $total
                    }
                }
            }
            
            if ($completed -lt $total) {
                Start-Sleep -Milliseconds 10
            }
        }
        
        $runspacePool.Close()
        $runspacePool.Dispose()
    }
    
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
