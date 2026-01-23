<#
.SYNOPSIS
    GitService - Manages Git operations for repositories
    
.DESCRIPTION
    Following SOLID principles:
    - SRP: Only responsible for Git operations
    - DIP: Provides abstraction for Git operations (others depend on this)
    - OCP: Can be extended with new Git operations
    
    This service handles:
    - Git status checking
    - Branch information
    - Uncommitted changes detection
    - Unpushed commits detection
    - Git validation
#>

class GitService {
    
    # Check if a directory is a Git repository
    [bool] IsGitRepository([string]$repoPath) {
        $gitPath = Join-Path $repoPath ".git"
        return Test-Path $gitPath
    }
    
    # Get current branch name
    [string] GetCurrentBranch([string]$repoPath) {
        if (-not $this.IsGitRepository($repoPath)) {
            return ""
        }
        
        Push-Location $repoPath
        try {
            $branch = git rev-parse --abbrev-ref HEAD 2>$null
            if ($LASTEXITCODE -eq 0) {
                return $branch
            }
            return ""
        }
        finally {
            Pop-Location
        }
    }
    
    # Check if repository has uncommitted changes
    [bool] HasUncommittedChanges([string]$repoPath) {
        if (-not $this.IsGitRepository($repoPath)) {
            return $false
        }
        
        Push-Location $repoPath
        try {
            $status = git status --porcelain 2>$null
            if ($LASTEXITCODE -eq 0) {
                return -not [string]::IsNullOrWhiteSpace($status)
            }
            return $false
        }
        finally {
            Pop-Location
        }
    }
    
    # Check if repository has unpushed commits
    [bool] HasUnpushedCommits([string]$repoPath) {
        if (-not $this.IsGitRepository($repoPath)) {
            return $false
        }
        
        Push-Location $repoPath
        try {
            # Get current branch
            $branch = $this.GetCurrentBranch($repoPath)
            if ([string]::IsNullOrWhiteSpace($branch)) {
                return $false
            }
            
            # Check if there are unpushed commits
            $unpushed = git log origin/$branch..HEAD 2>$null
            if ($LASTEXITCODE -eq 0) {
                return -not [string]::IsNullOrWhiteSpace($unpushed)
            }
            return $false
        }
        catch {
            return $false
        }
        finally {
            Pop-Location
        }
    }
    
    # Get complete Git status for a repository
    [GitStatusModel] GetGitStatus([string]$repoPath) {
        if (-not $this.IsGitRepository($repoPath)) {
            return [GitStatusModel]::new()
        }
        
        $branch = $this.GetCurrentBranch($repoPath)
        $hasUncommitted = $this.HasUncommittedChanges($repoPath)
        $hasUnpushed = $this.HasUnpushedCommits($repoPath)
        
        return [GitStatusModel]::new($true, $hasUncommitted, $hasUnpushed, $branch)
    }
    
    # Get Git status for a RepositoryModel
    [GitStatusModel] GetGitStatus([RepositoryModel]$repository) {
        return $this.GetGitStatus($repository.FullPath)
    }
    
    # Validate if a URL is a valid Git HTTPS URL
    [bool] IsValidGitUrl([string]$url) {
        return $url -match '^https://github\.com/[\w\-]+/[\w\-\.]+\.git$' -or 
               $url -match '^https://github\.com/[\w\-]+/[\w\-\.]+$'
    }
    
    # Extract repository name from Git URL
    [string] GetRepoNameFromUrl([string]$url) {
        if ($url -match '/([^/]+)\.git$' -or $url -match '/([^/]+)$') {
            return $matches[1]
        }
        return ""
    }
    
    # Clone a repository
    [bool] CloneRepository([string]$url, [string]$targetPath) {
        if (-not $this.IsValidGitUrl($url)) {
            Write-Error "Invalid Git URL format"
            return $false
        }
        
        # Ensure URL ends with .git
        if ($url -notmatch '\.git$') {
            $url = "$url.git"
        }
        
        Push-Location $targetPath
        try {
            git clone $url 2>&1 | Out-Null
            return $LASTEXITCODE -eq 0
        }
        catch {
            Write-Error "Error cloning repository: $_"
            return $false
        }
        finally {
            Pop-Location
        }
    }
    
    # Get remote URL for a repository
    [string] GetRemoteUrl([string]$repoPath) {
        if (-not $this.IsGitRepository($repoPath)) {
            return ""
        }
        
        Push-Location $repoPath
        try {
            $remoteUrl = git config --get remote.origin.url 2>$null
            if ($LASTEXITCODE -eq 0) {
                return $remoteUrl
            }
            return ""
        }
        finally {
            Pop-Location
        }
    }
}
