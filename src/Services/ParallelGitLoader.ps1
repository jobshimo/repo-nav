<#
.SYNOPSIS
    ParallelGitLoader - Handles parallel loading of Git status using Runspaces
    
.DESCRIPTION
    Following SOLID principles:
    - SRP: Only responsible for parallel Git status loading
    - DIP: Can be injected into RepositoryManager
    - OCP: Can be extended for different parallel strategies
    
    Extracted from RepositoryManager to separate parallel execution concerns.
#>

class ParallelGitLoader {
    # Configuration
    [int] $MaxConcurrency
    [int] $TimeoutSeconds = 30
    
    # Constructor
    ParallelGitLoader() {
        $this.MaxConcurrency = [Environment]::ProcessorCount
    }
    
    # Constructor with custom concurrency
    ParallelGitLoader([int]$maxConcurrency) {
        $this.MaxConcurrency = $maxConcurrency
    }
    
    <#
    .SYNOPSIS
        Loads Git status for multiple repositories in parallel
        
    .PARAMETER repos
        Array of RepositoryModel objects to load status for
        
    .PARAMETER progressCallback
        Optional callback for progress updates: { param($current, $total) }
    #>
    [void] LoadGitStatusParallel([array]$repos, [scriptblock]$progressCallback) {
        $total = $repos.Count
        
        if ($total -eq 0) { return }
        
        if ($null -ne $progressCallback) {
            & $progressCallback 0 $total
        }
        
        # Create runspace pool
        $runspacePool = [runspacefactory]::CreateRunspacePool(1, $this.MaxConcurrency)
        $runspacePool.Open()
        
        $runspaces = [System.Collections.Generic.List[hashtable]]::new()
        
        # Script block for parallel execution
        $scriptBlock = $this.GetGitStatusScriptBlock()
        
        # Start all runspaces
        foreach ($repo in $repos) {
            $powershell = [powershell]::Create().AddScript($scriptBlock).AddArgument($repo.FullPath)
            $powershell.RunspacePool = $runspacePool
            
            $runspaces.Add(@{
                PowerShell = $powershell
                Handle     = $powershell.BeginInvoke()
                Repository = $repo
            })
        }
        
        # Wait for completion and collect results
        $this.WaitAndCollectResults($runspaces, $total, $progressCallback)
        
        # Cleanup
        $runspacePool.Close()
        $runspacePool.Dispose()
    }
    
    <#
    .SYNOPSIS
        Returns the script block used for parallel Git status fetching
    #>
    hidden [scriptblock] GetGitStatusScriptBlock() {
        return {
            param([string]$repoPath)
            
            Set-StrictMode -Version Latest
            
            $local:isGitRepo = $false
            $local:branchResult = ""
            $local:hasChangesResult = $false
            $local:hasUnpushedResult = $false
            
            Push-Location $repoPath
            try {
                $local:isGitRepo = Test-Path ".git"
                if (-not $local:isGitRepo) {
                    return [PSCustomObject]@{
                        IsGitRepo            = $false
                        CurrentBranch        = ""
                        HasUncommittedChanges = $false
                        HasUnpushedCommits   = $false
                    }
                }
                
                # Get branch
                $local:branchOutput = git rev-parse --abbrev-ref HEAD 2>$null
                $local:branchResult = ($local:branchOutput | Out-String).Trim()
                
                # Get status
                $local:statusOutput = git status --porcelain 2>$null
                $local:statusStr = ($local:statusOutput | Out-String).Trim()
                $local:hasChangesResult = ($local:statusStr.Length -gt 0)
                
                # Get unpushed
                $local:upstream = git rev-parse --abbrev-ref "@{u}" 2>$null
                $local:unpushedCount = git rev-list --count "@{u}..HEAD" 2>$null
                $local:countStr = ($local:unpushedCount | Out-String).Trim()
                $local:hasUnpushedResult = $false
                if ($local:countStr -match '^\d+$') {
                    $local:hasUnpushedResult = ([int]$local:countStr -gt 0)
                }
                
                return [PSCustomObject]@{
                    IsGitRepo             = $local:isGitRepo
                    CurrentBranch         = $local:branchResult
                    HasUncommittedChanges = $local:hasChangesResult
                    HasUnpushedCommits    = $local:hasUnpushedResult
                }
            }
            finally {
                Pop-Location
            }
        }
    }
    
    <#
    .SYNOPSIS
        Waits for all runspaces to complete and collects results
    #>
    hidden [void] WaitAndCollectResults(
        [System.Collections.Generic.List[hashtable]]$runspaces, 
        [int]$total, 
        [scriptblock]$progressCallback
    ) {
        $completed = 0
        $startTime = Get-Date
        
        while ($completed -lt $total) {
            # Check timeout
            if (((Get-Date) - $startTime).TotalSeconds -gt $this.TimeoutSeconds) {
                break
            }
            
            foreach ($runspaceInfo in $runspaces) {
                if ($null -ne $runspaceInfo.Handle -and $runspaceInfo.Handle.IsCompleted) {
                    try {
                        $resultArray = $runspaceInfo.PowerShell.EndInvoke($runspaceInfo.Handle)
                        
                        if ($resultArray.Count -gt 0) {
                            $result = $resultArray[0]
                            
                            # Create GitStatusModel and update repository
                            $gitStatus = [GitStatusModel]::new(
                                $result.IsGitRepo,
                                $result.HasUncommittedChanges,
                                $result.HasUnpushedCommits,
                                $result.CurrentBranch
                            )
                            $runspaceInfo.Repository.SetGitStatus($gitStatus)
                        }
                    }
                    catch {
                        # Silently ignore errors for individual repos
                    }
                    finally {
                        $runspaceInfo.PowerShell.Dispose()
                        $runspaceInfo.Handle = $null
                    }
                    
                    $completed++
                    
                    if ($null -ne $progressCallback) {
                        & $progressCallback $completed $total
                    }
                }
            }
            
            if ($completed -lt $total) {
                Start-Sleep -Milliseconds 10
            }
        }
    }
}
