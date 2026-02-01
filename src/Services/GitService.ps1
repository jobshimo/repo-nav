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

class GitService : IGitService {
    
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
    [OperationResult] CloneRepository([string]$url, [string]$targetPath, [string]$folderName = "") {
        if (-not $this.IsValidGitUrl($url)) {
            return [OperationResult]::Fail("Invalid Git URL format")
        }
        
        # Ensure URL ends with .git
        if ($url -notmatch '\.git$') {
            $url = "$url.git"
        }
        
        Push-Location $targetPath
        try {
            if ([string]::IsNullOrWhiteSpace($folderName)) {
                $output = git clone $url 2>&1
            }
            else {
                $output = git clone $url $folderName 2>&1
            }
            $success = ($LASTEXITCODE -eq 0)
            $outStr = if ($output) { $output -join "`n" } else { "" }
            
            if ($success) {
                return [OperationResult]::Ok($null, $outStr)
            } else {
                return [OperationResult]::Fail($outStr)
            }
        }
        catch {
            return [OperationResult]::Fail($_.ToString())
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
    
    # Get HTTPS URL for repository (for browser)
    [string] GetRepoUrl([string]$repoPath) {
        $remote = $this.GetRemoteUrl($repoPath)
        if ([string]::IsNullOrWhiteSpace($remote)) { return "" }
        
        # Convert SSH to HTTPS if needed
        # git@github.com:User/Repo.git -> https://github.com/User/Repo
        if ($remote -match '^git@github\.com:(.+)\.git$') {
            return "https://github.com/$($matches[1])"
        }
        
        # HTTPS .git cleanup
        if ($remote -match '^(https://.+)\.git$') {
            return $matches[1]
        }
        
        return $remote
    }
    
    # Check if a directory contains Git repositories in its subdirectories
    # Returns the count of repositories found (0 if none)
    [int] CountContainedRepositories([string]$path) {
        $count = 0
        $subdirs = Get-ChildItem -Directory -Path $path -ErrorAction SilentlyContinue
        
        foreach ($subdir in $subdirs) {
            if ($this.IsGitRepository($subdir.FullName)) {
                $count++
            }
        }
        
        return $count
    }
    
    # Check if a directory is a container (has repos inside but is not a repo itself)
    [bool] IsContainerDirectory([string]$path) {
        # If it's already a git repo, it's not a container
        if ($this.IsGitRepository($path)) {
            return $false
        }
        
        # Check if any subdirectory is a git repo OR if the directory is empty/has no git repos but is structured to be one
        # Current logic: If it's not a git repo, treat as container so user can enter and create repos or folders there.
        # This allows navigating empty folder structures.
        return $true
    }

    # Get local branches
    [string[]] GetBranches([string]$repoPath) {
        if (-not $this.IsGitRepository($repoPath)) {
            return @()
        }
        
        Push-Location $repoPath
        try {
            # --format=%(refname:short) gives just the branch name
            $branches = git branch --format="%(refname:short)" 2>$null
            if ($LASTEXITCODE -eq 0 -and $branches) {
                return $branches
            }
            return @()
        }
        finally {
            Pop-Location
        }
    }

    # Create a new branch from a source branch
    [OperationResult] CreateBranch([string]$repoPath, [string]$newBranchName, [string]$sourceBranch) {
        if (-not $this.IsGitRepository($repoPath)) {
            return [OperationResult]::Fail("Not a git repository")
        }
        
        Push-Location $repoPath
        try {
            # git checkout -b new_branch source_branch
            $output = git checkout -b $newBranchName $sourceBranch 2>&1
            $success = ($LASTEXITCODE -eq 0)
            $outStr = if ($output) { $output -join "`n" } else { "" }
            
            if ($success) {
                return [OperationResult]::Ok($null, $outStr)
            } else {
                return [OperationResult]::Fail($outStr)
            }
        }
        catch {
             return [OperationResult]::Fail($_.ToString())
        }
        finally {
            Pop-Location
        }
    }

    # Checkout a branch
    [OperationResult] Checkout([string]$repoPath, [string]$branchName) {
        if (-not $this.IsGitRepository($repoPath)) {
            return [OperationResult]::Fail("Not a git repository")
        }
        
        Push-Location $repoPath
        try {
            $output = git checkout $branchName 2>&1
            $success = ($LASTEXITCODE -eq 0)
            
            # If success, output might be "Switched to branch..." which isn't an error.
            # Convert array to string if needed
            $outStr = if ($output) { $output -join "`n" } else { "" }
            
            if ($success) {
                return [OperationResult]::Ok($null, $outStr)
            } else {
                return [OperationResult]::Fail($outStr)
            }
        }
        catch {
             return [OperationResult]::Fail($_.ToString())
        }
        finally {
            Pop-Location
        }
    }

    # Merge a branch into the current branch
    [OperationResult] Merge([string]$repoPath, [string]$branchToMerge) {
        if (-not $this.IsGitRepository($repoPath)) {
            return [OperationResult]::Fail("Not a git repository")
        }
        
        Push-Location $repoPath
        try {
            $output = git merge $branchToMerge 2>&1
            $success = ($LASTEXITCODE -eq 0)
            $outStr = if ($output) { $output -join "`n" } else { "" }
            
            if ($success) {
                return [OperationResult]::Ok($null, $outStr)
            } else {
                return [OperationResult]::Fail($outStr)
            }
        }
        catch {
             return [OperationResult]::Fail($_.ToString())
        }
        finally {
            Pop-Location
        }
    }

    # Fetch changes from remote
    [OperationResult] Fetch([string]$repoPath) {
        if (-not $this.IsGitRepository($repoPath)) {
            return [OperationResult]::Fail("Not a git repository")
        }
        
        Push-Location $repoPath
        try {
            # Fetch with Prune to clean up deleted branches
            $output = git fetch --prune 2>&1
            $success = ($LASTEXITCODE -eq 0)
            $outStr = if ($output) { $output -join "`n" } else { "" }
            
            if ($success) {
                return [OperationResult]::Ok($null, $outStr)
            } else {
                return [OperationResult]::Fail($outStr)
            }
        }
        catch {
             return [OperationResult]::Fail($_.ToString())
        }
        finally {
            Pop-Location
        }
    }

    # Get remote branches
    [string[]] GetRemoteBranches([string]$repoPath) {
        if (-not $this.IsGitRepository($repoPath)) {
            return @()
        }
        
        Push-Location $repoPath
        try {
            # List remote branches, removing 'origin/' prefix for cleaner display if desired?
            # Or keep it to distinguish. Usually 'origin/main'.
            # -r = remotes
            $branches = git branch -r --format="%(refname:short)" 2>$null
            if ($LASTEXITCODE -eq 0 -and $branches) {
                # Filter out HEAD pointer (origin/HEAD -> origin/main)
                return @($branches) | Where-Object { $_ -notmatch "HEAD ->" }
            }
            return @()
        }
        finally {
            Pop-Location
        }
    }

    # Push a branch to remote
    [OperationResult] Push([string]$repoPath, [string]$branchName) {
        if (-not $this.IsGitRepository($repoPath)) {
            return [OperationResult]::Fail("Not a git repository")
        }
        
        Push-Location $repoPath
        try {
            # Push -u origin branchName
            $output = git push -u origin $branchName 2>&1
            $success = ($LASTEXITCODE -eq 0)
            $outStr = if ($output) { $output -join "`n" } else { "" }
            
            if ($success) {
                return [OperationResult]::Ok($null, $outStr)
            } else {
                return [OperationResult]::Fail($outStr)
            }
        }
        catch {
             return [OperationResult]::Fail($_.ToString())
        }
        finally {
            Pop-Location
        }
    }
    # Stage files
    [OperationResult] Add([string]$repoPath, [string]$filePattern) {
        if (-not $this.IsGitRepository($repoPath)) {
            return [OperationResult]::Fail("Not a git repository")
        }
        
        Push-Location $repoPath
        try {
            $output = git add $filePattern 2>&1
            $success = ($LASTEXITCODE -eq 0)
            $outStr = if ($output) { $output -join "`n" } else { "" }
            
            if ($success) {
                return [OperationResult]::Ok($null, $outStr)
            } else {
                return [OperationResult]::Fail($outStr)
            }
        }
        catch {
             return [OperationResult]::Fail($_.ToString())
        }
        finally {
            Pop-Location
        }
    }

    # Commit changes
    [OperationResult] Commit([string]$repoPath, [string]$message) {
        if (-not $this.IsGitRepository($repoPath)) {
            return [OperationResult]::Fail("Not a git repository")
        }
        
        Push-Location $repoPath
        try {
            # Use --no-verify to skip hooks if necessary, but standard is better
            $output = git commit -m $message 2>&1
            $success = ($LASTEXITCODE -eq 0)
            $outStr = if ($output) { $output -join "`n" } else { "" }
            
            if ($success) {
                return [OperationResult]::Ok($null, $outStr)
            } else {
                return [OperationResult]::Fail($outStr)
            }
        }
        catch {
             return [OperationResult]::Fail($_.ToString())
        }
        finally {
            Pop-Location
        }
    }

    # Stash changes
    [OperationResult] Stash([string]$repoPath, [string]$message = "") {
        if (-not $this.IsGitRepository($repoPath)) {
            return [OperationResult]::Fail("Not a git repository")
        }
        
        Push-Location $repoPath
        try {
            if ([string]::IsNullOrWhiteSpace($message)) {
                $output = git stash 2>&1
            } else {
                $output = git stash save "$message" 2>&1
            }
            $success = ($LASTEXITCODE -eq 0)
            $outStr = if ($output) { $output -join "`n" } else { "" }
            
            if ($success) {
                return [OperationResult]::Ok($null, $outStr)
            } else {
                return [OperationResult]::Fail($outStr)
            }
        }
        catch {
             return [OperationResult]::Fail($_.ToString())
        }
        finally {
            Pop-Location
        }
    }
    


    # Get branch tracking status (ahead/behind)
    [hashtable] GetBranchTrackingStatus([string]$repoPath, [string]$branchName) {
        if (-not $this.IsGitRepository($repoPath)) { return @{ Ahead = 0; Behind = 0 } }
        
        Push-Location $repoPath
        try {
            $upstream = git rev-parse --verify "${branchName}@{upstream}" 2>$null
            if ($LASTEXITCODE -ne 0) {
                return @{ Ahead = 0; Behind = 0 }
            }

            $counts = git rev-list --left-right --count "${branchName}...${branchName}@{upstream}" 2>$null
            
            if ($LASTEXITCODE -eq 0 -and $counts -match '(\d+)\s+(\d+)') {
                return @{ Ahead = [int]$matches[1]; Behind = [int]$matches[2] }
            }
            return @{ Ahead = 0; Behind = 0 }
        }
        catch { return @{ Ahead = 0; Behind = 0 } }
        finally { Pop-Location }
    }

    # Check if remote branch exists
    [bool] RemoteBranchExists([string]$repoPath, [string]$branchName) {
        if (-not $this.IsGitRepository($repoPath)) { return $false }
        
        Push-Location $repoPath
        try {
            $remoteRef = git rev-parse --verify "origin/${branchName}" 2>$null
            return ($LASTEXITCODE -eq 0)
        }
        finally { Pop-Location }
    }

    # Pull changes
    [OperationResult] Pull([string]$repoPath) {
        if (-not $this.IsGitRepository($repoPath)) {
            return [OperationResult]::Fail("Not a git repository")
        }
        
        Push-Location $repoPath
        try {
            $output = git pull 2>&1
            $success = ($LASTEXITCODE -eq 0)
            $outStr = if ($output) { $output -join "`n" } else { "" }
            
            if ($success) {
                return [OperationResult]::Ok($null, $outStr)
            } else {
                return [OperationResult]::Fail($outStr)
            }
        }
        catch { return [OperationResult]::Fail($_.ToString()) }
        finally { Pop-Location }
    }

    # Delete local branch
    [OperationResult] DeleteLocalBranch([string]$repoPath, [string]$branchName, [bool]$force) {
        if (-not $this.IsGitRepository($repoPath)) {
            return [OperationResult]::Fail("Not a git repository")
        }
        
        Push-Location $repoPath
        try {
            $flag = if ($force) { "-D" } else { "-d" }
            $output = git branch $flag $branchName 2>&1
            $success = ($LASTEXITCODE -eq 0)
            $outStr = if ($output) { $output -join "`n" } else { "" }
            
            if ($success) {
                return [OperationResult]::Ok($null, $outStr)
            } else {
                return [OperationResult]::Fail($outStr)
            }
        }
        catch { return [OperationResult]::Fail($_.ToString()) }
        finally { Pop-Location }
    }

    # Delete remote branch
    [OperationResult] DeleteRemoteBranch([string]$repoPath, [string]$branchName) {
        if (-not $this.IsGitRepository($repoPath)) {
            return [OperationResult]::Fail("Not a git repository")
        }
        
        Push-Location $repoPath
        try {
            $output = git push origin --delete $branchName 2>&1
            $success = ($LASTEXITCODE -eq 0)
            $outStr = if ($output) { $output -join "`n" } else { "" }
            
            if ($success) {
                return [OperationResult]::Ok($null, $outStr)
            } else {
                return [OperationResult]::Fail($outStr)
            }
        }
        catch { return [OperationResult]::Fail($_.ToString()) }
        finally { Pop-Location }
    }
}

