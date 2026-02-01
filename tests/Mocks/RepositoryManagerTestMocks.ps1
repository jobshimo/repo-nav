
# tests/Mocks/RepositoryManagerTestMocks.ps1

# Mock RepositoryOperationsService
class MockRepositoryOperationsService : IRepositoryOperationsService {
    [object] DeleteRepository([RepositoryModel]$repository, [bool]$force) {
        return [OperationResult]::Ok("Deleted successfully")
    }
    [object] DeleteFolder([RepositoryModel]$folder) {
        return [OperationResult]::Ok("Deleted folder")
    }
    [object] CloneRepository([string]$url, [string]$name, [string]$path) { return $null }
    [bool] IsFolderEmpty([string]$path) { return $true }
}

# Mock GitStatusManager
class MockGitStatusManager : IGitStatusManager {
    [void] LoadGitStatus([RepositoryModel]$repo, [bool]$force) {}
    [void] LoadGitStatusForRepos([array]$repos, [scriptblock]$callback, [bool]$force) {}
    [void] HydrateFromCache([RepositoryModel]$repo) {}
    [void] PerformAutoLoadGitStatus([array]$repos) {}
}

# Mock FavoriteServiceSpy
class MockFavoriteServiceSpy : IFavoriteService {
    [string] $RemoveCalledWith = $null
    
    [bool] RemoveFavorite([string]$repoPath) {
        $this.RemoveCalledWith = $repoPath
        return $true
    }
    
    # Stubs
    [string[]] GetFavorites() { return @() }
    [bool] IsFavorite([string]$p) { return $false }
    [bool] AddFavorite([string]$p) { return $true }
    [bool] ToggleFavorite([string]$p) { return $true }
    [int] GetFavoriteCount() { return 0 }
    [bool] ClearAllFavorites() { return $true }
    [void] UpdateRepositoryModel([RepositoryModel]$r) {}
}

# Mock ParallelGitLoader
class MockParallelGitLoader : IParallelGitLoader {
    [void] LoadGitStatusParallel([array]$repositories, [scriptblock]$progressCallback) {}
}
