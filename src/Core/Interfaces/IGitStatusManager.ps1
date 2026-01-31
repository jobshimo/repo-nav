<#
.SYNOPSIS
    IGitStatusManager - Interface for git status loading and caching
    
.DESCRIPTION
    Abstraction for git status management following DIP.
    Allows mocking in tests without actual git operations.
#>

class IGitStatusManager {
    # Load git status for a specific repository (and cache it)
    [void] LoadGitStatus([RepositoryModel]$repository, [bool]$force) {
        throw "Not Implemented: LoadGitStatus must be overridden"
    }
    
    # Load git status for multiple repositories in parallel
    [void] LoadGitStatusForAll([array]$repositories, [bool]$force) {
        throw "Not Implemented: LoadGitStatusForAll must be overridden"
    }
    
    # Get cached git status for a repository
    [GitStatusModel] GetCachedStatus([string]$repoPath) {
        throw "Not Implemented: GetCachedStatus must be overridden"
    }
    
    # Clear git status cache
    [void] ClearCache() {
        throw "Not Implemented: ClearCache must be overridden"
    }
    
    # Auto-load git status based on preferences
    [void] AutoLoadGitStatus([array]$repositories) {
        throw "Not Implemented: AutoLoadGitStatus must be overridden"
    }
}
