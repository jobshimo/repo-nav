<#
.SYNOPSIS
    GitStatusModel - Encapsulates Git repository status information
    
.DESCRIPTION
    Following SRP (Single Responsibility Principle):
    This class ONLY holds Git status data, no logic or operations.
    It's a Pure Data Transfer Object (DTO).
#>

class GitStatusModel {
    # Properties
    [bool] $IsGitRepo
    [bool] $HasUncommittedChanges
    [bool] $HasUnpushedCommits
    [string] $CurrentBranch
    [DateTime] $LoadedAt
    
    # Constructor with all parameters
    GitStatusModel(
        [bool]$isGitRepo,
        [bool]$hasUncommittedChanges,
        [bool]$hasUnpushedCommits,
        [string]$currentBranch
    ) {
        $this.IsGitRepo = $isGitRepo
        $this.HasUncommittedChanges = $hasUncommittedChanges
        $this.HasUnpushedCommits = $hasUnpushedCommits
        $this.CurrentBranch = $currentBranch
        $this.LoadedAt = Get-Date
    }
    
    # Constructor for non-git repositories
    GitStatusModel() {
        $this.IsGitRepo = $false
        $this.HasUncommittedChanges = $false
        $this.HasUnpushedCommits = $false
        $this.CurrentBranch = ""
        $this.LoadedAt = Get-Date
    }
    
    # Helper method to check if status is clean
    [bool] IsClean() {
        return $this.IsGitRepo -and 
               -not $this.HasUncommittedChanges -and 
               -not $this.HasUnpushedCommits
    }
    
    # Helper method to check if needs attention
    [bool] NeedsAttention() {
        return $this.IsGitRepo -and 
               ($this.HasUncommittedChanges -or $this.HasUnpushedCommits)
    }
    
    # Get status priority (for sorting/display)
    [int] GetPriority() {
        if (-not $this.IsGitRepo) { return 0 }
        if ($this.HasUncommittedChanges) { return 3 }  # Highest priority
        if ($this.HasUnpushedCommits) { return 2 }
        return 1  # Clean
    }
    
    # ToString for debugging
    [string] ToString() {
        if (-not $this.IsGitRepo) {
            return "Not a Git repository"
        }
        $status = "Branch: $($this.CurrentBranch)"
        if ($this.HasUncommittedChanges) {
            $status += " [Uncommitted]"
        }
        if ($this.HasUnpushedCommits) {
            $status += " [Unpushed]"
        }
        if ($this.IsClean()) {
            $status += " [Clean]"
        }
        return $status
    }
}
