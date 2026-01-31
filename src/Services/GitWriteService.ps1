<#
.SYNOPSIS
    GitWriteService - Handles state-changing Git operations (ISP)
#>
class GitWriteService {

    # Helper (Duplicated for standalone capability)
    [bool] IsGitRepository([string]$repoPath) {
        $gitPath = Join-Path $repoPath ".git"
        return Test-Path $gitPath
    }

    # Validate Git URL (Duplicated or should be in utility?)
    [bool] IsValidGitUrl([string]$url) {
        return $url -match '^https://github\.com/[\w\-]+/[\w\-\.]+\.git$' -or 
               $url -match '^https://github\.com/[\w\-]+/[\w\-\.]+$'
    }

    # Clone a repository
    [object] CloneRepository([string]$url, [string]$targetPath, [string]$folderName = "") {
        if (-not $this.IsValidGitUrl($url)) {
            return @{ Success = $false; Output = "Invalid Git URL format" }
        }
        
        if ($url -notmatch '\.git$') { $url = "$url.git" }
        
        Push-Location $targetPath
        try {
            if ([string]::IsNullOrWhiteSpace($folderName)) {
                $output = git clone $url 2>&1
            } else {
                $output = git clone $url $folderName 2>&1
            }
            $success = ($LASTEXITCODE -eq 0)
            $outStr = if ($output) { $output -join "`n" } else { "" }
            return @{ Success = $success; Output = $outStr }
        }
        catch { return @{ Success = $false; Output = $_.ToString() } }
        finally { Pop-Location }
    }

    # Create a new branch
    [object] CreateBranch([string]$repoPath, [string]$newBranchName, [string]$sourceBranch) {
        if (-not $this.IsGitRepository($repoPath)) {
            return @{ Success = $false; Output = "Not a git repository" }
        }
        
        Push-Location $repoPath
        try {
            $output = git checkout -b $newBranchName $sourceBranch 2>&1
            $success = ($LASTEXITCODE -eq 0)
            $outStr = if ($output) { $output -join "`n" } else { "" }
            return @{ Success = $success; Output = $outStr }
        }
        catch { return @{ Success = $false; Output = $_.ToString() } }
        finally { Pop-Location }
    }

    # Checkout a branch
    [object] Checkout([string]$repoPath, [string]$branchName) {
        if (-not $this.IsGitRepository($repoPath)) {
            return @{ Success = $false; Output = "Not a git repository" }
        }
        
        Push-Location $repoPath
        try {
            $output = git checkout $branchName 2>&1
            $success = ($LASTEXITCODE -eq 0)
            $outStr = if ($output) { $output -join "`n" } else { "" }
            return @{ Success = $success; Output = $outStr }
        }
        catch { return @{ Success = $false; Output = $_.ToString() } }
        finally { Pop-Location }
    }

    # Merge a branch
    [object] Merge([string]$repoPath, [string]$branchToMerge) {
        if (-not $this.IsGitRepository($repoPath)) {
            return @{ Success = $false; Output = "Not a git repository" }
        }
        
        Push-Location $repoPath
        try {
            $output = git merge $branchToMerge 2>&1
            $success = ($LASTEXITCODE -eq 0)
            $outStr = if ($output) { $output -join "`n" } else { "" }
            return @{ Success = $success; Output = $outStr }
        }
        catch { return @{ Success = $false; Output = $_.ToString() } }
        finally { Pop-Location }
    }

    # Fetch changes
    [object] Fetch([string]$repoPath) {
        if (-not $this.IsGitRepository($repoPath)) {
            return @{ Success = $false; Output = "Not a git repository" }
        }
        
        Push-Location $repoPath
        try {
            $output = git fetch --prune 2>&1
            $success = ($LASTEXITCODE -eq 0)
            $outStr = if ($output) { $output -join "`n" } else { "" }
            return @{ Success = $success; Output = $outStr }
        }
        catch { return @{ Success = $false; Output = $_.ToString() } }
        finally { Pop-Location }
    }

    # Push a branch
    [object] Push([string]$repoPath, [string]$branchName) {
        if (-not $this.IsGitRepository($repoPath)) {
            return @{ Success = $false; Output = "Not a git repository" }
        }
        
        Push-Location $repoPath
        try {
            $output = git push -u origin $branchName 2>&1
            $success = ($LASTEXITCODE -eq 0)
            $outStr = if ($output) { $output -join "`n" } else { "" }
            return @{ Success = $success; Output = $outStr }
        }
        catch { return @{ Success = $false; Output = $_.ToString() } }
        finally { Pop-Location }
    }

    # Stage files
    [object] Add([string]$repoPath, [string]$filePattern) {
        if (-not $this.IsGitRepository($repoPath)) {
            return @{ Success = $false; Output = "Not a git repository" }
        }
        
        Push-Location $repoPath
        try {
            $output = git add $filePattern 2>&1
            $success = ($LASTEXITCODE -eq 0)
            $outStr = if ($output) { $output -join "`n" } else { "" }
            return @{ Success = $success; Output = $outStr }
        }
        catch { return @{ Success = $false; Output = $_.ToString() } }
        finally { Pop-Location }
    }

    # Commit changes
    [object] Commit([string]$repoPath, [string]$message) {
        if (-not $this.IsGitRepository($repoPath)) {
            return @{ Success = $false; Output = "Not a git repository" }
        }
        
        Push-Location $repoPath
        try {
            $output = git commit -m $message 2>&1
            $success = ($LASTEXITCODE -eq 0)
            $outStr = if ($output) { $output -join "`n" } else { "" }
            return @{ Success = $success; Output = $outStr }
        }
        catch { return @{ Success = $false; Output = $_.ToString() } }
        finally { Pop-Location }
    }

    # Stash changes
    [object] Stash([string]$repoPath, [string]$message = "") {
        if (-not $this.IsGitRepository($repoPath)) {
            return @{ Success = $false; Output = "Not a git repository" }
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
            return @{ Success = $success; Output = $outStr }
        }
        catch { return @{ Success = $false; Output = $_.ToString() } }
        finally { Pop-Location }
    }
    # Pull changes
    [object] Pull([string]$repoPath) {
        if (-not $this.IsGitRepository($repoPath)) {
            return @{ Success = $false; Output = "Not a git repository" }
        }
        
        Push-Location $repoPath
        try {
            $output = git pull 2>&1
            $success = ($LASTEXITCODE -eq 0)
            $outStr = if ($output) { $output -join "`n" } else { "" }
            return @{ Success = $success; Output = $outStr }
        }
        catch { return @{ Success = $false; Output = $_.ToString() } }
        finally { Pop-Location }
    }

    # Delete local branch
    [object] DeleteLocalBranch([string]$repoPath, [string]$branchName, [bool]$force) {
        if (-not $this.IsGitRepository($repoPath)) {
            return @{ Success = $false; Output = "Not a git repository" }
        }
        
        Push-Location $repoPath
        try {
            $flag = if ($force) { "-D" } else { "-d" }
            $output = git branch $flag $branchName 2>&1
            $success = ($LASTEXITCODE -eq 0)
            $outStr = if ($output) { $output -join "`n" } else { "" }
            return @{ Success = $success; Output = $outStr }
        }
        catch { return @{ Success = $false; Output = $_.ToString() } }
        finally { Pop-Location }
    }

    # Delete remote branch
    [object] DeleteRemoteBranch([string]$repoPath, [string]$branchName) {
        if (-not $this.IsGitRepository($repoPath)) {
            return @{ Success = $false; Output = "Not a git repository" }
        }
        
        Push-Location $repoPath
        try {
            $output = git push origin --delete $branchName 2>&1
            $success = ($LASTEXITCODE -eq 0)
            $outStr = if ($output) { $output -join "`n" } else { "" }
            return @{ Success = $success; Output = $outStr }
        }
        catch { return @{ Success = $false; Output = $_.ToString() } }
        finally { Pop-Location }
    }
}

