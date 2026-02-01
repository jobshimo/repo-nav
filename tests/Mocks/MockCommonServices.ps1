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
    [void] HideCursor() {}
    [void] ShowCursor() {}
    [void] SetCursorPosition([int]$x, [int]$y) {}
    [int] GetCursorLeft() { return 0 }
    [int] GetCursorTop() { return 0 }
    [void] ClearScreen() {}
    [void] ClearForWorkflow() {}
    [bool] ConfirmAction([string]$prompt, [bool]$defaultYes) { return $true }
    [void] ClearCurrentLine() {}
    [void] ClearLine() {}
    [int] GetWindowHeight() { return 30 }
    [int] GetWindowWidth() { return 120 }
    [System.Management.Automation.Host.KeyInfo] ReadKey() { return $null }
    [void] Write([string]$text) {}
    [void] WriteColored([string]$text, [System.ConsoleColor]$color) {}
    [void] WriteLineColored([string]$text, [System.ConsoleColor]$color) {}
    [void] WriteWithBackground([string]$text, [System.ConsoleColor]$foreground, [System.ConsoleColor]$background) {}
    [void] WriteSeparator([string]$char, [int]$length, [System.ConsoleColor]$color) {}
    [void] NewLine() {}
    [void] WritePadded([string]$text, [System.ConsoleColor]$foregroundColor, [System.ConsoleColor]$backgroundColor) {}
    [void] ClearRestOfLine() {}
}

# ═════════════════════════════════════════════════════════════════════════════
# MOCK UI RENDERER
# ═════════════════════════════════════════════════════════════════════════════
class MockUIRenderer : IUIRenderer {
    # Header Rendering - All overloads
    [void] RenderHeader([string]$title) {}
    [void] RenderHeader([string]$title, [string]$subtitle) {}
    [void] RenderHeader([string]$title, [string]$subtitle, [string]$highlight) {}
    [void] RenderHeader([string]$title, [string]$subtitle, [string]$highlight, [ConsoleColor]$highlightColor) {}
    [void] RenderHeader([string]$title, [string]$subtitle, [string]$highlight, [ConsoleColor]$highlightColor, [ConsoleColor]$borderColor) {}

    # Breadcrumb
    [void] RenderBreadcrumb([string]$path) {}

    # Workflow Headers - All overloads
    [void] RenderWorkflowHeader([string]$title) {}
    [void] RenderWorkflowHeader([string]$title, [RepositoryModel]$repository) {}
    [void] RenderWorkflowHeaderWithInfo([string]$title, [RepositoryModel]$repository, [string]$infoLabel, [string]$infoValue, [ConsoleColor]$infoColor) {}

    # Menu
    [int] RenderMenu([string]$mode) { return 0 }

    # Repository List Rendering
    [void] RenderRepositoryItem([RepositoryModel]$repo, [bool]$isSelected) {}
    [void] RenderRepositoryList([NavigationState]$state, [int]$startLine) {}
    [void] UpdateRepositoryItemAt([int]$lineNumber, [RepositoryModel]$repo, [bool]$isSelected) {}

    # Color Picker Rendering
    [void] RenderColorItem([string]$color, [bool]$isSelected) {}
    [void] UpdateColorItemAt([int]$lineNumber, [string]$color, [bool]$isSelected) {}

    # Git Status Footer
    [void] ClearGitStatusFooter([int]$startLine) {}
    [void] RenderGitStatusFooter([RepositoryModel]$repo, [int]$totalItems, [int]$totalRepos, [int]$loadedRepos, [int]$currentIndex, [bool]$showHidden) {}

    # Messages
    [void] RenderError([string]$message) {}
    [void] RenderSuccess([string]$message) {}
    [void] RenderWarning([string]$message) {}
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
# MOCK GIT WRITE SERVICE (Extended for GitFlowCommand)
# ═════════════════════════════════════════════════════════════════════════════
class MockGitWriteService : IGitWriteService {
    [bool] IsValidGitUrl([string]$url) { return $true }
    [object] CloneRepository([string]$url, [string]$targetPath, [string]$folderName = "") {
        return @{ Success = $true; Output = "Cloned successfully" }
    }
    [object] CreateBranch([string]$repoPath, [string]$newBranchName, [string]$sourceBranch) {
        return @{ Success = $true; Message = "Branch created" }
    }
    [object] CheckoutBranch([string]$repoPath, [string]$branchName) {
        return @{ Success = $true; Message = "Checked out $branchName" }
    }
    [object] CommitChanges([string]$repoPath, [string]$message) {
        return @{ Success = $true; Message = "Committed" }
    }
    [object] PushChanges([string]$repoPath, [string]$branchName) {
        return @{ Success = $true; Message = "Pushed" }
    }
    [object] PullChanges([string]$repoPath) {
        return @{ Success = $true; Message = "Pulled" }
    }
}

# ═════════════════════════════════════════════════════════════════════════════
# MOCK GIT SERVICE WITH FLOW COMMAND METHODS
# Includes methods needed by GitFlowCommand
# ═════════════════════════════════════════════════════════════════════════════
class MockGitServiceExtended {
    [bool] IsGitRepository([string]$path) { return $true }
    [array] GetBranches([string]$path) { return @("main", "feature/1") }
    [string] GetCurrentBranch([string]$path) { return "main" }
    [object] GetBranchTrackingStatus([string]$path, [string]$branch) { 
        return [PSCustomObject]@{ Behind = 0; Ahead = 0 } 
    }
    [bool] RemoteBranchExists([string]$path, [string]$branch) { return $true }
    [bool] HasUncommittedChanges([string]$path) { return $false }
    [object] Checkout([string]$path, [string]$branch) { 
        return [PSCustomObject]@{ Success = $true; Message = "Ok" } 
    }
    [object] Pull([string]$path) { 
        return [PSCustomObject]@{ Success = $true } 
    }
    [object] DeleteLocalBranch([string]$path, [string]$branch, [bool]$force) { 
        return [PSCustomObject]@{ Success = $true } 
    }
    [object] DeleteRemoteBranch([string]$path, [string]$branch) { 
        return [PSCustomObject]@{ Success = $true } 
    }
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
    [void] LoadFallback() {}
    [void] SetLanguage([string]$languageCode) {}
    [void] LoadLanguage([string]$languageCode) {}
    [string] Get([string]$key) { return $key }
    [string] Get([string]$key, [object[]]$args) { 
        # Format the key with args for testing purposes
        if ($args -and $args.Count -gt 0) {
            return "$key : $($args -join ', ')"
        }
        return $key 
    }
    [string] GetCurrentLanguage() { return "en" }
    [string[]] GetAvailableLanguages() { return @("en", "es") }
}

# ═════════════════════════════════════════════════════════════════════════════
# MOCK HIDDEN REPOS SERVICE
# ═════════════════════════════════════════════════════════════════════════════
class MockHiddenReposService : IHiddenReposService {
    [bool] $ToggleCalled = $false
    [bool] $AddCalled = $false
    [bool] $RemoveCalled = $false
    [bool] $ClearCalled = $false
    
    [bool] IsHidden([string]$repoPath) { return $false }
    [bool] AddToHidden([string]$repoPath) { $this.AddCalled = $true; return $true }
    [bool] RemoveFromHidden([string]$repoPath) { $this.RemoveCalled = $true; return $true }
    [string[]] GetHiddenList() { return @() }
    [int] GetHiddenCount() { return 0 }
    [bool] ClearAllHidden() { $this.ClearCalled = $true; return $true }
    [bool] ToggleShowHidden() { $this.ToggleCalled = $true; return $true }
    [bool] GetShowHiddenState() { return $true }
    [void] SetShowHiddenState([bool]$show) {}
}

# ═════════════════════════════════════════════════════════════════════════════
# MOCK PROGRESS INDICATOR
# ═════════════════════════════════════════════════════════════════════════════
class MockProgressIndicator : IProgressIndicator {
    [bool] $RenderCalled = $false
    [bool] $CompleteCalled = $false
    [string] $LastMessage
    [int] $LastCurrent
    [int] $LastTotal

    [void] RenderProgressBar([string]$message, [int]$current, [int]$total) {
        $this.RenderCalled = $true
        $this.LastMessage = $message
        $this.LastCurrent = $current
        $this.LastTotal = $total
    }

    [void] CompleteProgressBar() {
        $this.CompleteCalled = $true
    }
    
    [void] ShowLoadingDots([string]$message, [scriptblock]$action) {
        & $action
    }
    
    # IProgressReporter interface methods (inherited)
    [void] Report([string]$message, [int]$current, [int]$total) {
        $this.RenderProgressBar($message, $current, $total)
    }
    [void] Complete() {
        $this.CompleteProgressBar()
    }
}

# ═════════════════════════════════════════════════════════════════════════════
# MOCK OPTION SELECTOR
# ═════════════════════════════════════════════════════════════════════════════
class MockOptionSelector : IOptionSelector {
    [object] $ReturnValue = $false
    
    MockOptionSelector() : base() {}
    MockOptionSelector([IConsoleHelper]$console) : base($console) {}

    [object] Show([SelectionOptions]$config) { return $this.ReturnValue }
    [bool] SelectYesNo([string]$question, [object]$localizationService, [bool]$clearScreen) { return [bool]$this.ReturnValue }
    [bool] SelectYesNo([string]$question) { return [bool]$this.ReturnValue }
    [bool] SelectYesNo([string]$question, [bool]$clearScreen) { return [bool]$this.ReturnValue }
    
    [void] SetReturnValue([object]$value) { $this.ReturnValue = $value }
}

# ═════════════════════════════════════════════════════════════════════════════
# MOCK USER PREFERENCES SERVICE
# ═════════════════════════════════════════════════════════════════════════════
class MockUserPreferencesService : IUserPreferencesService {
    [PSCustomObject] LoadPreferences() { return [PSCustomObject]@{} }
    [bool] SavePreferences([PSCustomObject]$preferences) { return $true }
    [PSCustomObject] CreateDefaultPreferences() { return [PSCustomObject]@{} }
    [bool] PreferencesExists() { return $true }
    [object] GetPreference([string]$section, [string]$key) { return $null }
    [bool] SetPreference([string]$section, [string]$key, [object]$value) { return $true }
    [bool] TogglePreference([string]$section, [string]$key) { return $true }
    [void] EnsurePathInPreferences([string]$path) {}
}
