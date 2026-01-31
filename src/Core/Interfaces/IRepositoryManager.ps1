
# Base Class acting as Interface (PowerShell 5/7 does not support native interfaces in script)
class IRepositoryManager {
    # Core Loading
    [void] LoadRepositories() {}
    [void] LoadRepositories([string]$basePath) {}
    [void] LoadRepositories([string]$basePath, [bool]$forceReload) {}
    [void] LoadRepositoriesInternal([string]$basePath, [string]$parentPath) {}
    [void] LoadContainerRepositories([string]$containerPath, [string]$parentPath) {}
    
    # Repository Access
    [RepositoryModel[]] GetRepositories() { return @() }
    [array] GetAllRepositoriesRecursive([string]$basePath) { return @() }
    [RepositoryModel] GetRepository([string]$name) { return $null }
    
    # Operations
    [OperationResult] CloneRepository([string]$url, [string]$customName, [string]$basePath) { return $null }
    [OperationResult] DeleteRepository([RepositoryModel]$repository) { return $null }
    [OperationResult] DeleteRepository([RepositoryModel]$repository, [bool]$force) { return $null }
    [OperationResult] DeleteFolder([RepositoryModel]$folder) { return $null }
    [bool] IsFolderEmpty([string]$folderPath) { return $false }
    
    # Git Status
    [void] LoadGitStatus([RepositoryModel]$repository) {}
    [void] LoadGitStatus([RepositoryModel]$repository, [bool]$force) {}
    [void] LoadAllGitStatus() {}
    [void] LoadMissingGitStatus([scriptblock]$progressCallback) {}
    [void] LoadGitStatusForRepos([array]$repos) {}
    [void] LoadGitStatusForRepos([array]$repos, [scriptblock]$progressCallback) {}
    [void] LoadGitStatusForRepos([array]$repos, [scriptblock]$progressCallback, [bool]$force) {}
    [void] PerformAutoLoadGitStatus([array]$repos, [object]$console) {}
    [int] GetLoadedGitStatusCount() { return 0 }
    [void] RefreshRepository([RepositoryModel]$repository) {}
    
    # Features
    [bool] SetAlias([RepositoryModel]$repository, [AliasInfo]$aliasInfo) { return $false }
    [bool] RemoveAlias([RepositoryModel]$repository) { return $false }
    [bool] ToggleFavorite([RepositoryModel]$repository) { return $false }
    [bool] InstallDependencies([RepositoryModel]$repository) { return $false }
    [bool] RemoveNodeModules([RepositoryModel]$repository, [bool]$removePackageLock) { return $false }
}
