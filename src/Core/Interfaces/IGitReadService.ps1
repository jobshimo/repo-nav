<#
.SYNOPSIS
    IGitReadService - Interface for read-only Git operations
    
.DESCRIPTION
    Abstraction for read-only Git operations following ISP.
    Segregates read operations from write operations.
#>

class IGitReadService {
    # Check if a directory is a Git repository
    [bool] IsGitRepository([string]$repoPath) {
        throw "Not Implemented: IsGitRepository must be overridden"
    }
    
    # Get current branch name
    [string] GetCurrentBranch([string]$repoPath) {
        throw "Not Implemented: GetCurrentBranch must be overridden"
    }
    
    # Check if repository has uncommitted changes
    [bool] HasUncommittedChanges([string]$repoPath) {
        throw "Not Implemented: HasUncommittedChanges must be overridden"
    }
    
    # Check if repository has unpushed commits
    [bool] HasUnpushedCommits([string]$repoPath) {
        throw "Not Implemented: HasUnpushedCommits must be overridden"
    }
    
    # Get number of commits ahead of origin
    [int] GetCommitsAhead([string]$repoPath) {
        throw "Not Implemented: GetCommitsAhead must be overridden"
    }
    
    # Get number of commits behind origin
    [int] GetCommitsBehind([string]$repoPath) {
        throw "Not Implemented: GetCommitsBehind must be overridden"
    }
}
