<#
.SYNOPSIS
    GitStatusManager - Manages git status loading and caching
    
.DESCRIPTION
    Extracts Git status responsibilities from RepositoryManager to adhere to SRP.
    Handles:
    - Loading git status for single or multiple repositories
    - Caching git status results
    - Parallel loading via ParallelGitLoader
    - Auto-loading based on preferences
#>

class GitStatusManager {
    # Dependencies
    [GitService] $GitService
    [IParallelGitLoader] $ParallelLoader
    [IUserPreferencesService] $PreferencesService
    [IProgressReporter] $ProgressReporter
    
    # Cache for git status: [Path] -> [GitStatusModel]
    [hashtable] $GitStatusCache
    
    # Constructor
    GitStatusManager(
        [GitService]$gitService, 
        [IParallelGitLoader]$parallelLoader, 
        [IUserPreferencesService]$preferencesService,
        [IProgressReporter]$progressReporter
    ) {
        $this.GitService = $gitService
        $this.ParallelLoader = $parallelLoader
        $this.PreferencesService = $preferencesService
        $this.ProgressReporter = $progressReporter
        $this.GitStatusCache = @{}
    }
    
    # Load git status for a specific repository (and cache it)
    [void] LoadGitStatus([RepositoryModel]$repository, [bool]$force) {
        # Skip containers
        if ($repository.IsContainer) { return }
        
        # Smart Caching: Skip if recently checked (within 10s) and not forced
        $now = Get-Date
        if (-not $force -and $repository.HasGitStatusLoaded() -and 
            ($now - $repository.LastStatusCheck).TotalSeconds -lt 10) {
            return
        }
        
        $gitStatus = $this.GitService.GetGitStatus($repository)
        $repository.SetGitStatus($gitStatus)
        $repository.LastStatusCheck = $now
        
        # Cache the git status by full path
        $this.GitStatusCache[$repository.FullPath] = $gitStatus
    }
    
    # Load git status for multiple repositories (delegates to ParallelGitLoader)
    [void] LoadGitStatusForRepos([array]$repos, [scriptblock]$progressCallback, [bool]$force) {
        # Filter out containers
        $reposToLoad = @($repos | Where-Object { -not $_.IsContainer })
        
        # Smart Caching for batch
        if (-not $force) {
            $now = Get-Date
            $reposToLoad = @($reposToLoad | Where-Object { 
                -not $_.HasGitStatusLoaded() -or ($now - $_.LastStatusCheck).TotalSeconds -ge 10
            })
        }
        $total = $reposToLoad.Count
        
        if ($total -eq 0) { return }
        
        # Delegate to ParallelGitLoader
        $this.ParallelLoader.LoadGitStatusParallel($reposToLoad, $progressCallback)
        
        # Cache the loaded git status
        foreach ($repo in $reposToLoad) {
            if ($repo.HasGitStatusLoaded()) {
                $this.GitStatusCache[$repo.FullPath] = $repo.GitStatus
            }
        }
    }
    
    # Auto-load based on preferences
    [void] PerformAutoLoadGitStatus([array]$repos) {
         if (-not $this.PreferencesService) { return }

         $mode = $this.PreferencesService.GetPreference("git", "autoLoadGitStatusMode")
         if (-not $mode) { $mode = "None" }
         
         if ($mode -ne "None") {
             $toLoad = @()
             $msg = ""
             
             if ($mode -eq "Favorites") {
                 $toLoad = $repos | Where-Object { $_.IsFavorite -and -not $_.HasGitStatusLoaded() }
                 $msg = "favorites"
             } elseif ($mode -eq "All") {
                 $toLoad = $repos | Where-Object { -not $_.HasGitStatusLoaded() }
                 $msg = "all"
             }
             
              if ($toLoad.Count -gt 0) {
                  $reporter = $this.ProgressReporter
                  $progressCallback = {
                     param([int]$c, [int]$t)
                     $reporter.Report("Loading git status ($msg)", $c, $t)
                  }
                  
                  $this.LoadGitStatusForRepos($toLoad, $progressCallback, $false)
                  $reporter.Complete()
              }
         }
    }
    
    # Hydrate repository with cached status if available
    [void] HydrateFromCache([RepositoryModel]$repo) {
        if ($this.GitStatusCache.ContainsKey($repo.FullPath)) {
            $repo.SetGitStatus($this.GitStatusCache[$repo.FullPath])
        }
    }
}
