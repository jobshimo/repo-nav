
# tests/Mocks/MockRepositoryManager.ps1

class MockRepositoryManager : IRepositoryManager {
    # Properties to hold mock return values
    [RepositoryModel[]] $Repositories
    [RepositoryModel] $RepositoryToReturn
    [OperationResult] $OperationResult
    [bool] $BooleanResult
    [int] $IntResult
    
    # Tracking method calls (Simple Spy)
    [System.Collections.ArrayList] $MethodCalls
    [int] $RefreshRepositoryCallCount
    
    MockRepositoryManager() {
        $this.Repositories = @()
        $this.OperationResult = [OperationResult]::Ok("Mock Success")
        $this.BooleanResult = $true
        $this.IntResult = 0
        $this.MethodCalls = [System.Collections.ArrayList]::new()
        $this.RefreshRepositoryCallCount = 0
    }
    
    # Helper to track calls
    [void] TrackCall([string]$methodName, [object[]]$args) {
        $this.MethodCalls.Add(@{ Method = $methodName; Args = $args })
    }
    
    # --- Interface Implementation ---
    
    [void] LoadRepositories() { $this.TrackCall("LoadRepositories", @()) }
    [void] LoadRepositories([string]$basePath) { $this.TrackCall("LoadRepositories", @($basePath)) }
    [void] LoadRepositories([string]$basePath, [bool]$forceReload) { $this.TrackCall("LoadRepositories", @($basePath, $forceReload)) }
    [void] LoadRepositoriesInternal([string]$basePath, [string]$parentPath) { $this.TrackCall("LoadRepositoriesInternal", @($basePath, $parentPath)) }
    [void] LoadContainerRepositories([string]$containerPath, [string]$parentPath) { $this.TrackCall("LoadContainerRepositories", @($containerPath, $parentPath)) }
    
    [RepositoryModel[]] GetRepositories() { 
        $this.TrackCall("GetRepositories", @())
        return $this.Repositories 
    }
    
    [array] GetAllRepositoriesRecursive([string]$basePath) {
        $this.TrackCall("GetAllRepositoriesRecursive", @($basePath))
        return $this.Repositories
    }
    
    [RepositoryModel] GetRepository([string]$name) {
        $this.TrackCall("GetRepository", @($name))
        return $this.RepositoryToReturn
    }
    
    [OperationResult] CloneRepository([string]$url, [string]$customName, [string]$basePath) {
        $this.TrackCall("CloneRepository", @($url, $customName, $basePath))
        return $this.OperationResult
    }
    
    [OperationResult] DeleteRepository([RepositoryModel]$repository) {
        $this.TrackCall("DeleteRepository", @($repository))
        return $this.OperationResult
    }
    
    [OperationResult] DeleteRepository([RepositoryModel]$repository, [bool]$force) {
        $this.TrackCall("DeleteRepository", @($repository, $force))
        return $this.OperationResult
    }
    
    [OperationResult] DeleteFolder([RepositoryModel]$folder) {
        $this.TrackCall("DeleteFolder", @($folder))
        return $this.OperationResult
    }
    
    [bool] IsFolderEmpty([string]$folderPath) {
        $this.TrackCall("IsFolderEmpty", @($folderPath))
        return $this.BooleanResult
    }
    
    [void] LoadGitStatus([RepositoryModel]$repository) { $this.TrackCall("LoadGitStatus", @($repository)) }
    [void] LoadGitStatus([RepositoryModel]$repository, [bool]$force) { $this.TrackCall("LoadGitStatus", @($repository, $force)) }
    [void] LoadAllGitStatus() { $this.TrackCall("LoadAllGitStatus", @()) }
    [void] LoadMissingGitStatus([scriptblock]$progressCallback) { $this.TrackCall("LoadMissingGitStatus", @($progressCallback)) }
    [void] LoadGitStatusForRepos([array]$repos) { $this.TrackCall("LoadGitStatusForRepos", @($repos)) }
    [void] LoadGitStatusForRepos([array]$repos, [scriptblock]$progressCallback) { $this.TrackCall("LoadGitStatusForRepos", @($repos, $progressCallback)) }
    [void] LoadGitStatusForRepos([array]$repos, [scriptblock]$progressCallback, [bool]$force) { $this.TrackCall("LoadGitStatusForRepos", @($repos, $progressCallback, $force)) }
    [void] PerformAutoLoadGitStatus([array]$repos, [object]$console) { $this.TrackCall("PerformAutoLoadGitStatus", @($repos, $console)) }
    
    [int] GetLoadedGitStatusCount() {
        $this.TrackCall("GetLoadedGitStatusCount", @())
        return $this.IntResult
    }
    
    [void] RefreshRepository([RepositoryModel]$repository) { 
        $this.TrackCall("RefreshRepository", @($repository))
        $this.RefreshRepositoryCallCount++
    }
    
    [bool] SetAlias([RepositoryModel]$repository, [AliasInfo]$aliasInfo) {
        $this.TrackCall("SetAlias", @($repository, $aliasInfo))
        return $this.BooleanResult
    }
    
    [bool] RemoveAlias([RepositoryModel]$repository) {
        $this.TrackCall("RemoveAlias", @($repository))
        return $this.BooleanResult
    }
    
    [bool] ToggleFavorite([RepositoryModel]$repository) {
        $this.TrackCall("ToggleFavorite", @($repository))
        return $this.BooleanResult
    }
    
    [bool] InstallDependencies([RepositoryModel]$repository) {
        $this.TrackCall("InstallDependencies", @($repository))
        return $this.BooleanResult
    }
    
    [bool] RemoveNodeModules([RepositoryModel]$repository, [bool]$removePackageLock) {
        $this.TrackCall("RemoveNodeModules", @($repository, $removePackageLock))
        return $this.BooleanResult
    }
}
