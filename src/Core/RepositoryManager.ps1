<#
.SYNOPSIS
    RepositoryManager - Coordinates all repository operations
    
.DESCRIPTION
    Following SOLID principles:
    - SRP: Coordinates repository operations (delegates to specialized services)
    - OCP: Open for extension (new operations), closed for modification
    - DIP: Depends on service abstractions (GitService, NpmService, etc.)
    - Composition over Inheritance: Uses services through composition
    
    This is the "Facade" that provides high-level operations:
    - Loading and initializing repositories
    - Setting/removing aliases
    - Delegating to specialized services for:
      - Favorites (FavoriteService)
      - Parallel Git loading (ParallelGitLoader)
      - Clone/Delete operations (RepositoryOperationsService)
#>

class RepositoryManager {
    # Dependencies (injected)
    [GitService] $GitService
    [NpmService] $NpmService
    [AliasManager] $AliasManager
    [ConfigurationService] $ConfigService
    [UserPreferencesService] $PreferencesService
    [FavoriteService] $FavoriteService
    [ParallelGitLoader] $ParallelGitLoader
    [RepositoryOperationsService] $RepoOperationsService
    
    # Cache for loaded repositories
    [System.Collections.ArrayList] $Repositories
    
    # Constructor with dependency injection
    RepositoryManager(
        [GitService]$gitService,
        [NpmService]$npmService,
        [AliasManager]$aliasManager,
        [ConfigurationService]$configService,
        [UserPreferencesService]$preferencesService,
        [FavoriteService]$favoriteService,
        [ParallelGitLoader]$parallelGitLoader,
        [RepositoryOperationsService]$repoOperationsService
    ) {
        $this.GitService = $gitService
        $this.NpmService = $npmService
        $this.AliasManager = $aliasManager
        $this.ConfigService = $configService
        $this.PreferencesService = $preferencesService
        $this.FavoriteService = $favoriteService
        $this.ParallelGitLoader = $parallelGitLoader
        $this.RepoOperationsService = $repoOperationsService
        $this.Repositories = [System.Collections.ArrayList]::new()
    }
    
    # Clone a new repository (delegates to RepositoryOperationsService)
    # Returns a result object { Success: bool, Message: string }
    [hashtable] CloneRepository([string]$url, [string]$customName, [string]$basePath) {
        return $this.RepoOperationsService.CloneRepository($url, $customName, $basePath)
    }

    # Delete a repository (delegates to RepositoryOperationsService)
    # Returns a result object { Success: bool, Message: string }
    [hashtable] DeleteRepository([RepositoryModel]$repository) {
        # Ensure git status is loaded for safety check
        if (-not $repository.HasGitStatusLoaded()) {
            $this.LoadGitStatus($repository)
        }
        
        $result = $this.RepoOperationsService.DeleteRepository($repository, $false)
        
        if ($result.Success) {
            # Remove alias if exists
            if ($repository.HasAlias) {
                $this.RemoveAlias($repository)
            }
            
            # Remove from favorites
            $this.FavoriteService.RemoveFavorite($repository.Name)
            
            # Remove from local list
            if ($this.Repositories.Contains($repository)) {
                $this.Repositories.Remove($repository)
            }
        }
        
        return $result
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
        
        foreach ($dir in $directories) {
            $repo = [RepositoryModel]::new($dir)
            
            if ($aliases.ContainsKey($repo.Name)) {
                $repo.SetAlias($aliases[$repo.Name])
            }
            
            # Delegate favorite check to FavoriteService
            $this.FavoriteService.UpdateRepositoryModel($repo)
            
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
    
    # Load git status for specified repositories (delegates to ParallelGitLoader)
    [void] LoadGitStatusForRepos([array]$repos, [scriptblock]$progressCallback = $null) {
        $total = @($repos).Count
        
        if ($total -eq 0) { return }
        
        # Delegate to ParallelGitLoader
        $this.ParallelGitLoader.LoadGitStatusParallel($repos, $progressCallback)
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
    
    # Toggle favorite status (delegates to FavoriteService)
    [bool] ToggleFavorite([RepositoryModel]$repository) {
        $result = $this.FavoriteService.ToggleFavorite($repository.Name)
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
