<#
.SYNOPSIS
    Mock implementation of RepositoryManager for testing
    
.DESCRIPTION
    Provides a lightweight mock that tracks method calls without
    performing actual Git/file system operations.
    
.EXAMPLE
    $mock = [MockRepositoryManager]::new()
    $mock.AddFakeRepository("TestRepo", "C:\Repos\Test")
    $repos = $mock.GetRepositories()
#>

class MockRepositoryManager {
    [System.Collections.ArrayList] $Repositories
    [System.Collections.ArrayList] $MethodCalls
    
    MockRepositoryManager() {
        $this.Repositories = [System.Collections.ArrayList]::new()
        $this.MethodCalls = [System.Collections.ArrayList]::new()
    }
    
    # Test helper: Add fake repository
    [void] AddFakeRepository([string]$name, [string]$path) {
        $repo = [RepositoryModel]::new()
        $repo.Name = $name
        $repo.FullPath = $path
        $repo.IsGitRepository = $true
        $this.Repositories.Add($repo) | Out-Null
    }
    
    [void] LoadRepositories([string]$basePath) {
        $this.MethodCalls.Add(@{
            Method = "LoadRepositories"
            Args = @{ BasePath = $basePath }
        }) | Out-Null
    }
    
    [array] GetRepositories() {
        $this.MethodCalls.Add(@{
            Method = "GetRepositories"
            Args = @{}
        }) | Out-Null
        return $this.Repositories.ToArray()
    }
    
    [OperationResult] SetAlias([RepositoryModel]$repo, [string]$alias, [ConsoleColor]$color) {
        $this.MethodCalls.Add(@{
            Method = "SetAlias"
            Args = @{ Repo = $repo.Name; Alias = $alias; Color = $color }
        }) | Out-Null
        return [OperationResult]::Ok()
    }
    
    [OperationResult] RemoveAlias([RepositoryModel]$repo) {
        $this.MethodCalls.Add(@{
            Method = "RemoveAlias"
            Args = @{ Repo = $repo.Name }
        }) | Out-Null
        return [OperationResult]::Ok()
    }
    
    [void] ToggleFavorite([RepositoryModel]$repo) {
        $this.MethodCalls.Add(@{
            Method = "ToggleFavorite"
            Args = @{ Repo = $repo.Name }
        }) | Out-Null
    }
    
    [bool] IsFavorite([RepositoryModel]$repo) {
        return $false
    }
    
    # Test helper: Check if method was called
    [bool] WasMethodCalled([string]$methodName) {
        foreach ($call in $this.MethodCalls) {
            if ($call.Method -eq $methodName) {
                return $true
            }
        }
        return $false
    }
    
    # Test helper: Get call count
    [int] GetCallCount([string]$methodName) {
        $count = 0
        foreach ($call in $this.MethodCalls) {
            if ($call.Method -eq $methodName) {
                $count++
            }
        }
        return $count
    }
    
    # Test helper: Reset for next test
    [void] Reset() {
        $this.Repositories.Clear()
        $this.MethodCalls.Clear()
    }
}
