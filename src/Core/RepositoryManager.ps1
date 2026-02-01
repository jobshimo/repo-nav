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

class RepositoryManager : IRepositoryManager {
    # Dependencies (injected)
    [GitService] $GitService
    [GitReadService] $GitReadService
    [GitWriteService] $GitWriteService
    [NpmService] $NpmService
    [AliasManager] $AliasManager
    [UserPreferencesService] $PreferencesService
    [FavoriteService] $FavoriteService
    [ParallelGitLoader] $ParallelGitLoader
    [RepositoryOperationsService] $RepoOperationsService
    [IProgressReporter] $ProgressReporter
    [GitStatusManager] $GitStatusManager
    [RepositorySorter] $Sorter
    [HiddenReposService] $HiddenReposService
    
    # Cache for loaded repositories
    [System.Collections.ArrayList] $Repositories
    
    # Internal Cache
    [System.Collections.ArrayList] $RawRepositoriesCache
    [string] $CachedBasePath
    
    # GitStatusCache is now managed by GitStatusManager
    
    # Constructor with dependency injection
    RepositoryManager(
        [GitService]$gitService,
        [GitReadService]$gitReadService,
        [GitWriteService]$gitWriteService,
        [NpmService]$npmService,
        [AliasManager]$aliasManager,
        [UserPreferencesService]$preferencesService,
        [FavoriteService]$favoriteService,
        [ParallelGitLoader]$parallelGitLoader,
        [RepositoryOperationsService]$repoOperationsService,
        [IProgressReporter]$progressReporter,
        [GitStatusManager]$gitStatusManager,
        [RepositorySorter]$sorter,
        [HiddenReposService]$hiddenReposService
    ) {
        $this.GitService = $gitService
        $this.GitReadService = $gitReadService
        $this.GitWriteService = $gitWriteService
        $this.NpmService = $npmService
        $this.AliasManager = $aliasManager
        $this.AliasManager = $aliasManager
        $this.PreferencesService = $preferencesService
        $this.FavoriteService = $favoriteService
        $this.ParallelGitLoader = $parallelGitLoader
        $this.RepoOperationsService = $repoOperationsService
        $this.ProgressReporter = $progressReporter
        $this.GitStatusManager = $gitStatusManager
        $this.Sorter = $sorter
        $this.HiddenReposService = $hiddenReposService
        $this.Repositories = [System.Collections.ArrayList]::new()
        $this.RawRepositoriesCache = [System.Collections.ArrayList]::new()
        $this.CachedBasePath = ""
    }
    
    # Clone a new repository (delegates to RepositoryOperationsService)
    # Returns a result object { Success: bool, Message: string }
    [OperationResult] CloneRepository([string]$url, [string]$customName, [string]$basePath) {
        return $this.RepoOperationsService.CloneRepository($url, $customName, $basePath)
    }

    # Delete a repository (delegates to RepositoryOperationsService)
    # Returns a result object { Success: bool, Message: string, RequiresForce: bool }
    [OperationResult] DeleteRepository([RepositoryModel]$repository) {
        return $this.DeleteRepository($repository, $false)
    }
    
    # Delete repository with optional force flag
    # Returns a result object { Success: bool, Message: string, RequiresForce: bool }
    [OperationResult] DeleteRepository([RepositoryModel]$repository, [bool]$force) {
        # Ensure git status is loaded for safety check
        if (-not $repository.HasGitStatusLoaded()) {
            $this.LoadGitStatus($repository)
        }
        
        $result = $this.RepoOperationsService.DeleteRepository($repository, $force)
        
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
    
    # Delete a folder (delegates to RepositoryOperationsService)
    # Returns a result object { Success: bool, Message: string }
    [OperationResult] DeleteFolder([RepositoryModel]$folder) {
        $result = $this.RepoOperationsService.DeleteFolder($folder)
        
        if ($result.Success) {
            # Remove from local list if strictly necessary, but usually reload happens after
            if ($this.Repositories.Contains($folder)) {
                $this.Repositories.Remove($folder)
            }
        }
        
        return $result
    }

    # Reload using cached base path (Perf optimization / Convenience)
    [void] LoadRepositories() {
        if (-not [string]::IsNullOrEmpty($this.CachedBasePath)) {
            $this.LoadRepositoriesInternal($this.CachedBasePath, $null, $false)
        }
    }

    # Load repositories from base path
    # Now supports container folders (folders with repos inside)
    # Accepts optional forceReload flag to bypass cache
    [void] LoadRepositories([string]$basePath) {
        $this.LoadRepositoriesInternal($basePath, $null, $false)
    }
    
    [void] LoadRepositories([string]$basePath, [bool]$forceReload) {
        $this.LoadRepositoriesInternal($basePath, $null, $forceReload)
    }
    
    # Load repositories with optional parent path (for hierarchical navigation)
    [void] LoadRepositoriesInternal([string]$basePath, [string]$parentPath) {
        $this.LoadRepositoriesInternal($basePath, $parentPath, $false)
    }

    [void] LoadRepositoriesInternal([string]$basePath, [string]$parentPath, [bool]$forceReload) {
        $oldRepos = @{}
        foreach ($repo in $this.Repositories) {
            $oldRepos[$repo.Name] = $repo
        }
        
        $this.Repositories.Clear()
        
        # Get hidden repos list and visibility state
        $hiddenRepos = @()
        $showHidden = $true
        if ($null -ne $this.HiddenReposService) {
            $hiddenRepos = $this.HiddenReposService.GetHiddenList()
            $showHidden = $this.HiddenReposService.GetShowHiddenState()
        }
        
        # Cache Logic: Load from disk only if needed
        if ($forceReload -or ($basePath -ne $this.CachedBasePath) -or ($this.RawRepositoriesCache.Count -eq 0)) {
            $this.RawRepositoriesCache.Clear()
            $this.CachedBasePath = $basePath
            
            $directories = Get-ChildItem -Directory -Path $basePath | 
                           Where-Object { $_.Name -notin @('envs', 'classes') }
                           
            $aliases = $this.AliasManager.GetAllAliases()

            if ($directories.Count -gt 0) {
                 foreach ($dir in $directories) {
                    $repo = [RepositoryModel]::new($dir)
                    
                    # Basic initialization that doesn't depend on filters
                    if ($this.GitService.IsContainerDirectory($dir.FullName)) {
                        $repoCount = $this.GitService.CountContainedRepositories($dir.FullName)
                        $repo.MarkAsContainer($repoCount)
                    }
                    
                    if ($parentPath) {
                        $repo.SetParentPath($parentPath)
                    }
                    
                    # Alias
                    if ($aliases.ContainsKey($repo.FullPath)) {
                        $repo.SetAlias($aliases[$repo.FullPath])
                    } elseif ($aliases.ContainsKey($repo.Name)) {
                        $repo.SetAlias($aliases[$repo.Name])
                    }
                    
                    # NPM (Only for non-containers)
                    if (-not $repo.IsContainer) {
                        $this.NpmService.UpdateRepositoryModel($repo)
                    }
                    
                    # Add to raw cache
                    $this.RawRepositoriesCache.Add($repo) | Out-Null
                 }
            }
        }
        
        # Apply Filters (Hidden, Favorites, GitStatus) to items from Cache
        foreach ($repo in $this.RawRepositoriesCache) {
            # Update dynamic properties (Favorites can change)
            $this.FavoriteService.UpdateRepositoryModel($repo)
            
            # Update hidden status check
            $isHidden = $repo.FullPath -in $hiddenRepos
            $repo.MarkAsHidden($isHidden)
            
            # Filter
            if ($showHidden -or -not $isHidden) {
                # Hydrate Git Status (Cached in GitStatusManager, so fast)
                $this.GitStatusManager.HydrateFromCache($repo)
                
                $this.Repositories.Add($repo) | Out-Null
            }
        }
        
        # Get user preference for favorites position
        [bool]$favoritesOnTop = $this.PreferencesService.GetPreference("display", "favoritesOnTop")
        
        # Delegate sorting to RepositorySorter (SRP)
        $sorted = $this.Sorter.Sort($this.Repositories, $favoritesOnTop)
        
        $this.Repositories.Clear()
        $this.Repositories.AddRange($sorted)
    }
    
    # Load repositories from a container folder (for hierarchical navigation)
    [void] LoadContainerRepositories([string]$containerPath, [string]$parentPath) {
        $this.LoadRepositoriesInternal($containerPath, $parentPath, $false)
    }
    
    # Get all loaded repositories
    [RepositoryModel[]] GetRepositories() {
        return $this.Repositories.ToArray()
    }
    
    # Get all repositories recursively from base path (for search)
    # Returns only actual repositories, not container folders
    [array] GetAllRepositoriesRecursive([string]$basePath) {
        $allRepos = [System.Collections.ArrayList]::new()
        $aliases = $this.AliasManager.GetAllAliases()
        
        # Recursively scan for git repositories
        $this.ScanRepositoriesRecursive($basePath, $allRepos, $aliases)
        
        return $allRepos.ToArray()
    }
    
    # Helper method for recursive repository scanning
    hidden [void] ScanRepositoriesRecursive([string]$path, [System.Collections.ArrayList]$results, [hashtable]$aliases) {
        $directories = Get-ChildItem -Directory -Path $path -ErrorAction SilentlyContinue |
                       Where-Object { $_.Name -notin @('envs', 'classes', 'node_modules', '.git') }
        
        foreach ($dir in $directories) {
            $isGitRepo = Test-Path (Join-Path $dir.FullName ".git")
            
            if ($isGitRepo) {
                # This is a repository - add it
                $repo = [RepositoryModel]::new($dir)
                
                if ($aliases.ContainsKey($repo.FullPath)) {
                    $repo.SetAlias($aliases[$repo.FullPath])
                } elseif ($aliases.ContainsKey($repo.Name)) {
                    $repo.SetAlias($aliases[$repo.Name])
                }
                
                $this.FavoriteService.UpdateRepositoryModel($repo)
                
                [void]$results.Add($repo)
            } else {
                # Not a git repo - check if it's a container with repos inside
                $this.ScanRepositoriesRecursive($dir.FullName, $results, $aliases)
            }
        }
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
        $this.GitStatusManager.LoadGitStatus($repository, $false)
    }

    [void] LoadGitStatus([RepositoryModel]$repository, [bool]$force) {
        $this.GitStatusManager.LoadGitStatus($repository, $force)
    }
    
    # Load git status for all repositories
    [void] LoadAllGitStatus() {
        $this.LoadGitStatusForRepos($this.Repositories)
    }
    
    # Load git status only for repositories that don't have it (excludes containers)
    # Accepts optional progress callback: { param($current, $total) }
    [void] LoadMissingGitStatus([scriptblock]$progressCallback = $null) {
        $missingRepos = $this.Repositories | Where-Object { -not $_.IsContainer -and -not $_.HasGitStatusLoaded() }
        $this.LoadGitStatusForRepos($missingRepos, $progressCallback)
    }
    
    # Load git status for specified repositories (delegates to GitStatusManager)
    # Overload 1: Only repos
    [void] LoadGitStatusForRepos([array]$repos) {
        $this.GitStatusManager.LoadGitStatusForRepos($repos, $null, $false)
    }

    # Overload 2: Repos + Callback
    [void] LoadGitStatusForRepos([array]$repos, [scriptblock]$progressCallback) {
        $this.GitStatusManager.LoadGitStatusForRepos($repos, $progressCallback, $false)
    }

    # Overload 3: All parameters
    [void] LoadGitStatusForRepos([array]$repos, [scriptblock]$progressCallback, [bool]$force) {
        $this.GitStatusManager.LoadGitStatusForRepos($repos, $progressCallback, $force)
    }

    <#
    .SYNOPSIS
        Checks user preferences and loads git status automatically
    #>
    [void] PerformAutoLoadGitStatus([array]$repos, [object]$console) {
         $this.GitStatusManager.PerformAutoLoadGitStatus($repos)
    }
    
    [int] GetLoadedGitStatusCount() {
        $count = 0
        foreach ($repo in $this.Repositories) {
            if (-not $repo.IsContainer -and $repo.HasGitStatusLoaded()) {
                $count++
            }
        }
        return $count
    }
    
    # Set alias for a repository
    [bool] SetAlias([RepositoryModel]$repository, [AliasInfo]$aliasInfo) {
        if ($this.AliasManager.SetAlias($repository.FullPath, $aliasInfo)) {
            $repository.SetAlias($aliasInfo)
            return $true
        }
        return $false
    }
    
    # Remove alias from a repository
    [bool] RemoveAlias([RepositoryModel]$repository) {
        if ($this.AliasManager.RemoveAlias($repository.FullPath)) {
            $repository.RemoveAlias()
            return $true
        }
        return $false
    }
    
    # Toggle favorite status
    [bool] ToggleFavorite([RepositoryModel]$repository) {
        $result = $this.FavoriteService.ToggleFavorite($repository.FullPath)
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
            $this.LoadGitStatus($repository, $true)
        }
    }


    
    # Check if folder is empty (delegates to RepositoryOperationsService)
    [bool] IsFolderEmpty([string]$folderPath) {
        return $this.RepoOperationsService.IsFolderEmpty($folderPath)
    }
}
