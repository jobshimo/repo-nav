<#
.SYNOPSIS
    MockCommonServices - Reusable mock implementations for testing
    
.DESCRIPTION
    This file provides standard mock implementations of core service interfaces.
    These mocks follow the Interface Pattern and can be reused across multiple test files.
    
.USAGE
    # In your test file:
    . "$PSScriptRoot\..\..\Mocks\MockCommonServices.ps1"
    
    # Then use directly:
    $mockNpm = New-Object MockNpmService
    $mockConsole = New-Object MockConsoleHelper
    $mockState = New-Object MockNavigationState
    
.NOTES
    All mocks implement their corresponding interfaces to ensure type compatibility.
    Load directly like any other PowerShell class file - no Invoke-Expression needed.
#>

# ═════════════════════════════════════════════════════════════════════════════
# MOCK NAVIGATION STATE
# ═════════════════════════════════════════════════════════════════════════════
class MockNavigationState : NavigationState {
    [array] $Repos = @()
    [int] $CurrentIndex = 0

    MockNavigationState() : base(@()) {}
    [void] Stop() {}
    [void] Resume() {}
    [void] MarkForFullRedraw() {}
    [void] SetRepositories([array]$repos) { $this.Repos = $repos }
    [void] SetCurrentIndex([int]$i) { $this.CurrentIndex = $i }
    [array] GetRepositories() { return $this.Repos }
    [int] GetCurrentIndex() { return $this.CurrentIndex }
}

# ═════════════════════════════════════════════════════════════════════════════
# MOCK NPM SERVICE
# ═════════════════════════════════════════════════════════════════════════════
class MockNpmService : INpmService {
    [bool] HasPackageJson([string]$repoPath) { return $true }
    [bool] HasNodeModules([string]$repoPath) { return $true }
    [bool] HasPackageLock([string]$repoPath) { return $false }
    [bool] InstallDependencies([string]$repoPath) { return $true }
    [bool] RemoveNodeModules([string]$repoPath, [bool]$removePackageLock = $false) { return $true }
    [double] GetNodeModulesSize([string]$repoPath) { return 150.5 }
    [PSCustomObject] GetPackageInfo([string]$repoPath) { 
        return [PSCustomObject]@{ name = "test"; version = "1.0.0" } 
    }
    [string] GetNpmExecutablePath() { return "npm" }
}

# ═════════════════════════════════════════════════════════════════════════════
# MOCK JOB SERVICE
# ═════════════════════════════════════════════════════════════════════════════
class MockJobService : IJobService {
    [object] StartJob([scriptblock]$script, [object[]]$args) {
        return [PSCustomObject]@{ 
            State = 'Completed'
            ChildJobs = @([PSCustomObject]@{ Error = $null })
        }
    }
    [object] WaitJob([object]$job) { return $null }
    [object] ReceiveJob([object]$job) { return $true }
    [void] RemoveJob([object]$job, [bool]$force) { }
}

# ═════════════════════════════════════════════════════════════════════════════
# MOCK CONSOLE HELPER
# ═════════════════════════════════════════════════════════════════════════════
class MockConsoleHelper : IConsoleHelper {
    [void] ClearForWorkflow() {}
    [void] WriteLineColored([string]$message, [string]$color) {}
    [bool] ConfirmAction([string]$prompt) { return $true }
    [void] Clear() {}
    [void] WriteLine([string]$text) {}
    [void] Write([string]$text) {}
    [void] WriteHost([string]$text, [string]$color) {}
    [void] SetCursorPosition([int]$x, [int]$y) {}
    [PSCustomObject] GetCursorPosition() { return [PSCustomObject]@{ X = 0; Y = 0 } }
    [int] GetWindowWidth() { return 120 }
    [int] GetWindowHeight() { return 30 }
}

# ═════════════════════════════════════════════════════════════════════════════
# MOCK UI RENDERER
# ═════════════════════════════════════════════════════════════════════════════
class MockUIRenderer : IUIRenderer {
    [void] RenderWorkflowHeader([string]$title, [object]$repo) {}
    [void] RenderError([string]$message) {}
    [void] RenderMenu([array]$repos, [int]$selected, [int]$start, [int]$pageSize) {}
    [void] RenderRepositoryList([array]$repos, [int]$selected, [int]$viewportStart, [int]$pageSize) {}
    [string] RenderStatusLine([object]$state) { return "" }
}

# ═════════════════════════════════════════════════════════════════════════════
# MOCK GIT SERVICE
# ═════════════════════════════════════════════════════════════════════════════
class MockGitService : IGitService {
    [bool] IsGitRepository([string]$repoPath) { return $true }
    [string] GetCurrentBranch([string]$repoPath) { return "main" }
    [bool] HasUncommittedChanges([string]$repoPath) { return $false }
    [bool] HasUnpushedCommits([string]$repoPath) { return $false }
    [GitStatusModel] GetGitStatus([string]$repoPath) { 
        return [GitStatusModel]::new()
    }
    [bool] IsValidGitUrl([string]$url) { return $true }
    [string] ExtractRepoNameFromUrl([string]$url) { return "test-repo" }
}

# ═════════════════════════════════════════════════════════════════════════════
# MOCK ALIAS MANAGER
# ═════════════════════════════════════════════════════════════════════════════
class MockAliasManager : IAliasManager {
    [hashtable] GetAllAliases() { return @{} }
    [AliasInfo] GetAlias([string]$identifier) { return $null }
    [bool] SetAlias([string]$repoPath, [string]$alias, [string]$color) { return $true }
    [bool] RemoveAlias([string]$identifier) { return $true }
    [bool] HasAlias([string]$identifier) { return $false }
    [bool] IsAliasNameTaken([string]$alias) { return $false }
}

# ═════════════════════════════════════════════════════════════════════════════
# MOCK FAVORITE SERVICE
# ═════════════════════════════════════════════════════════════════════════════
class MockFavoriteService : IFavoriteService {
    [string[]] GetFavorites() { return @() }
    [bool] IsFavorite([string]$repoPath) { return $false }
    [bool] AddFavorite([string]$repoPath) { return $true }
    [bool] RemoveFavorite([string]$repoPath) { return $true }
    [bool] ToggleFavorite([string]$repoPath) { return $true }
    [int] GetFavoriteCount() { return 0 }
    [bool] ClearAllFavorites() { return $true }
}

# ═════════════════════════════════════════════════════════════════════════════
# MOCK SEARCH SERVICE
# ═════════════════════════════════════════════════════════════════════════════
class MockSearchService : ISearchService {
    [array] FilterRepositories([array]$allRepos, [string]$searchText) { 
        return $allRepos 
    }
    [RepositoryModel] FindByName([array]$allRepos, [string]$name) { 
        return $null 
    }
    [RepositoryModel] FindByAlias([array]$allRepos, [string]$alias) { 
        return $null 
    }
}

# ═════════════════════════════════════════════════════════════════════════════
# MOCK LOGGER SERVICE
# ═════════════════════════════════════════════════════════════════════════════
class MockLoggerService : ILoggerService {
    [void] LogDebug([string]$message) {}
    [void] LogInfo([string]$message) {}
    [void] LogWarning([string]$message) {}
    [void] LogError([string]$message) {}
    [void] LogError([string]$message, [System.Management.Automation.ErrorRecord]$error) {}
}

# ═════════════════════════════════════════════════════════════════════════════
# MOCK LOCALIZATION SERVICE
# ═════════════════════════════════════════════════════════════════════════════
class MockLocalizationService : ILocalizationService {
    [string] Get([string]$key) { return $key }
    [string] Get([string]$key, [hashtable]$params) { return $key }
    [string] GetCurrentLanguage() { return "en" }
    [void] SetLanguage([string]$language) {}
}
