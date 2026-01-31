<#
.SYNOPSIS
    IGitWriteService - Interface for state-changing Git operations
    
.DESCRIPTION
    Abstraction for write Git operations following ISP.
    Segregates write operations from read operations.
#>

class IGitWriteService {
    # Validate Git URL format
    [bool] IsValidGitUrl([string]$url) {
        throw "Not Implemented: IsValidGitUrl must be overridden"
    }
    
    # Clone a repository
    [object] CloneRepository([string]$url, [string]$targetPath, [string]$folderName = "") {
        throw "Not Implemented: CloneRepository must be overridden"
    }
    
    # Create a new branch
    [object] CreateBranch([string]$repoPath, [string]$newBranchName, [string]$sourceBranch) {
        throw "Not Implemented: CreateBranch must be overridden"
    }
    
    # Checkout a branch
    [object] CheckoutBranch([string]$repoPath, [string]$branchName) {
        throw "Not Implemented: CheckoutBranch must be overridden"
    }
    
    # Commit changes
    [object] CommitChanges([string]$repoPath, [string]$message) {
        throw "Not Implemented: CommitChanges must be overridden"
    }
    
    # Push changes
    [object] PushChanges([string]$repoPath, [string]$branchName) {
        throw "Not Implemented: PushChanges must be overridden"
    }
    
    # Pull changes
    [object] PullChanges([string]$repoPath) {
        throw "Not Implemented: PullChanges must be overridden"
    }
}
