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
    [GitReadService] $GitReadService
    [GitWriteService] $GitWriteService
    [NpmService] $NpmService
    [AliasManager] $AliasManager
    [ConfigurationService] $ConfigService
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
    
    # GitStatusCache is now managed by GitStatusManager
    
    # Constructor with dependency injection
    RepositoryManager(
        [GitService]$gitService,
        [GitReadService]$gitReadService,
        [GitWriteService]$gitWriteService,
        [NpmService]$npmService,
        [AliasManager]$aliasManager,
        [ConfigurationService]$configService,
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
        $this.ConfigService = $configService
        $this.PreferencesService = $preferencesService
        $this.FavoriteService = $favoriteService
        $this.ParallelGitLoader = $parallelGitLoader
        $this.RepoOperationsService = $repoOperationsService
        $this.ProgressReporter = $progressReporter
        $this.GitStatusManager = $gitStatusManager
        $this.Sorter = $sorter
        $this.HiddenReposService = $hiddenReposService
        $this.Repositories = [System.Collections.ArrayList]::new()
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

    # Load all repositories from base path
    # Now supports container folders (folders with repos inside)
    [void] LoadRepositories([string]$basePath) {
        $this.LoadRepositoriesInternal($basePath, $null)
    }
    
    # Load repositories with optional parent path (for hierarchical navigation)
    [void] LoadRepositoriesInternal([string]$basePath, [string]$parentPath) {
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
        
        $directories = Get-ChildItem -Directory -Path $basePath | 
                       Where-Object { $_.Name -notin @('envs', 'classes', 'repo-nav') } |
                       Where-Object { $showHidden -or ($_.FullName -notin $hiddenRepos) }
        
        if ($directories.Count -eq 0) {
            return
        }
        
        $aliases = $this.AliasManager.GetAllAliases()
        
        foreach ($dir in $directories) {
            $repo = [RepositoryModel]::new($dir)
            
            # Check if this is a container (has repos inside but is not a repo itself)
            # With new logic in GitService, any non-git-repo directory is a container
            if ($this.GitService.IsContainerDirectory($dir.FullName)) {
                $repoCount = $this.GitService.CountContainedRepositories($dir.FullName)
                $repo.MarkAsContainer($repoCount)
            }
            
            # Set parent path if provided (for back navigation)
            if ($parentPath) {
                $repo.SetParentPath($parentPath)
            }
            
            if ($aliases.ContainsKey($repo.FullPath)) {
                $repo.SetAlias($aliases[$repo.FullPath])
            } elseif ($aliases.ContainsKey($repo.Name)) {
                $repo.SetAlias($aliases[$repo.Name])
            }
            
            # Delegate favorite check to FavoriteService (already updated to use FullPath inside)
            $this.FavoriteService.UpdateRepositoryModel($repo)
            
            # Only check node_modules for non-container folders
            if (-not $repo.IsContainer) {
                $this.NpmService.UpdateRepositoryModel($repo)
            }
            
            # Hydrate from GitStatusManager cache
            $this.GitStatusManager.HydrateFromCache($repo)
            
            # Mark as hidden if applicable (check FullPath)
            if ($repo.FullPath -in $hiddenRepos) {
                $repo.MarkAsHidden($true)
            }
            
            $this.Repositories.Add($repo) | Out-Null
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
        $this.LoadRepositoriesInternal($containerPath, $parentPath)
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
                       Where-Object { $_.Name -notin @('envs', 'classes', 'repo-nav', 'node_modules', '.git') }
        
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
