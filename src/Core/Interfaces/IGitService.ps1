<#
.SYNOPSIS
    IGitService - Interface for Git operations
    
.DESCRIPTION
    Abstraction for Git operations following DIP.
    Allows mocking in tests without actual git commands.
#>

class IGitService {
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
    
    # Get complete Git status for a repository
    [GitStatusModel] GetGitStatus([string]$repoPath) {
        throw "Not Implemented: GetGitStatus must be overridden"
    }
    
    # Validate if a string is a valid Git URL
    [bool] IsValidGitUrl([string]$url) {
        throw "Not Implemented: IsValidGitUrl must be overridden"
    }
    
    # Extract repository name from Git URL
    [string] ExtractRepoNameFromUrl([string]$url) {
        throw "Not Implemented: ExtractRepoNameFromUrl must be overridden"
    }
}
