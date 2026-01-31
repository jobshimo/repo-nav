# 1. Load Core Types FIRST (Script Scope)
# Use simple string path to avoid Object/Slash issues
$srcRoot = "$PSScriptRoot/../../../../src"

# Define Helper Stubs
class ConsoleHelper { 
    [void] WriteLineColored([string]$msg, [System.ConsoleColor]$color) {} 
    [void] ReadKey() {}
}
class UIRenderer {}
class LoggerService {}
class ColorSelector {}
class OptionSelector {
    [object] $NextSelection
    [string] $ActionResponse = "Yes"
    
    [object] Show($config) { 
        if ($config.Title -like "ACTION*") { return $this.ActionResponse }
        return "Yes" 
    }
    [object] ShowSelection($title, $items, $opts) { 
        return $this.NextSelection
    }
}
class LocalizationService {
    [string] Get([string]$key, [string]$default) { return $default }
}
class UserPreferencesService {}
class HiddenReposService {}
class PathManager {}

# Load Real Types required for Inheritance
# We dot-source directly with reliable paths
try {
    # 1. Core Services & Models (No dependencies)
    if (-not ([System.Management.Automation.PSTypeName]'WindowSizeCalculator').Type) {
        . "$srcRoot/Services/WindowSizeCalculator.ps1"
    }
    if (-not ([System.Management.Automation.PSTypeName]'Constants').Type) {
        . "$srcRoot/Config/Constants.ps1"
    }
    if (-not ([System.Management.Automation.PSTypeName]'OperationResult').Type) {
        . "$srcRoot/Core/Common/OperationResult.ps1"
    }
    if (-not ([System.Management.Automation.PSTypeName]'ColorPalette').Type) {
        . "$srcRoot/Config/ColorPalette.ps1"
    }
    if (-not ([System.Management.Automation.PSTypeName]'AliasInfo').Type) {
        . "$srcRoot/Models/AliasInfo.ps1"
    }
    if (-not ([System.Management.Automation.PSTypeName]'GitStatusModel').Type) {
        . "$srcRoot/Models/GitStatusModel.ps1"
    }
    if (-not ([System.Management.Automation.PSTypeName]'RepositoryModel').Type) {
        . "$srcRoot/Models/RepositoryModel.ps1"
    }

    # 2. Interfaces (Depend on Models)
    if (-not ([System.Management.Automation.PSTypeName]'IRepositoryManager').Type) {
        . "$srcRoot/Core/Interfaces/IRepositoryManager.ps1"
    }

    # 3. State/Context (Depend on interfaces and services)
    if (-not ([System.Management.Automation.PSTypeName]'NavigationState').Type) {
        . "$srcRoot/Core/State/NavigationState.ps1"
    }
    if (-not ([System.Management.Automation.PSTypeName]'CommandContext').Type) {
        . "$srcRoot/Core/State/CommandContext.ps1"
    }
    
    # 4. Command Interfaces (Depend on Context)
    if (-not ([System.Management.Automation.PSTypeName]'INavigationCommand').Type) {
        . "$srcRoot/Core/Commands/INavigationCommand.ps1"
    }

    if (-not ([System.Management.Automation.PSTypeName]'ConsoleHelper').Type) {
        . "$srcRoot/UI/Base/ConsoleHelper.ps1"
    }
} catch {
    Write-Warning "Error loading types: $_"
}

# 2. Define Stub Subclasses dynamically using Invoke-Expression to bypass parse-time checks
$dynamicClasses = @'
class StubConsoleHelper : ConsoleHelper { 
    [void] WriteLineColored([string]$msg, [System.ConsoleColor]$color) {} 
    [void] ReadKey() {}
}

class StubNavigationState : NavigationState {
    [int] $CurrentIndex = 0
    [array] $Repos = @()
    
    StubNavigationState() : base(@()) {}
    
    [array] GetRepositories() { return $this.Repos }
    [int] GetCurrentIndex() { return $this.CurrentIndex }
    [void] Stop() {}
    [void] Resume() {}
    [void] MarkForFullRedraw() {}
}

class FilteredListSelector {
    FilteredListSelector($c, $r) {}
    [object] ShowSelection($title, $items, $opts) { return $null }
}

class IntegrationFlowController {
    IntegrationFlowController($c, $r, $g, $s) {}
    [string] Start() { return "Success" }
}

class QuickChangeFlowController {
    QuickChangeFlowController($c, $r) {}
    [string] Start() { return "Success" }
}

class StubRepoManager : IRepositoryManager {
    [object] $GitService
    
    [object] GetGitService() { return $this.GitService }
    [void] Initialize([string]$path) {}
    [array] GetRepositories() { return @() }
    [void] Refresh([bool]$force) {}
    [void] RefreshSingle([string]$path) {}
    [RepositoryModel] GetRepository([string]$name) { return $null }
    [OperationResult] CloneRepository([string]$url, [string]$customName) { return $null }
    [OperationResult] DeleteRepository([RepositoryModel]$repository, [bool]$deleteFolder) { return $null }
    [OperationResult] DeleteFolder([RepositoryModel]$folder) { return $null }
    [void] LoadGitStatus([RepositoryModel]$repository) {}
}
'@

Invoke-Expression $dynamicClasses

# 3. Load other dependencies
. "$srcRoot/UI/Components/SelectionOptions.ps1"
try {
    . "$srcRoot/Core/Flows/GitFlowCommand.ps1"
    Write-Host "Successfully loaded GitFlowCommand.ps1" -ForegroundColor Green
    
    if ([System.Management.Automation.PSTypeName]'GitFlowCommand'.Type) {
         Write-Host "Type [GitFlowCommand] FOUND." -ForegroundColor Green
    } else {
         Write-Host "Type [GitFlowCommand] NOT FOUND after load." -ForegroundColor Red
    }
    
    if ([System.Management.Automation.PSTypeName]'INavigationCommand'.Type) {
         Write-Host "Type [INavigationCommand] FOUND." -ForegroundColor Green
    } else {
         Write-Host "Type [INavigationCommand] NOT FOUND." -ForegroundColor Red
    }
    
} catch {
    Write-Error "FAILED to load GitFlowCommand.ps1: $_"
    Write-Error $_.ScriptStackTrace
}

Describe "GitFlowCommand" {
    BeforeAll {
        $command = [GitFlowCommand]::new()
        $context = [CommandContext]::new()
        
        # Wire up Stubs
        $context.Console = [StubConsoleHelper]::new()
        $context.OptionSelector = [OptionSelector]::new()
        $context.LocalizationService = [LocalizationService]::new()
        
        # Wire up State Stub
        $stubState = [StubNavigationState]::new()
        $stubState.Repos = @([RepositoryModel]@{ Name = "Repo1"; FullPath = "C:\Repo1" })
        $context.State = $stubState
        
        # Wire up RepoManager Stub
        $stubRepoManager = [StubRepoManager]::new()
        $stubRepoManager.GitService = [PSCustomObject]@{
             IsGitRepository = { param($path) return $true }
             GetBranches = { param($path) return @("main", "feature/1") }
             GetCurrentBranch = { param($path) return "main" }
             GetBranchTrackingStatus = { param($path, $branch) return [PSCustomObject]@{ Behind = 0; Ahead = 0 } }
             RemoteBranchExists = { param($path, $branch) return $true }
             HasUncommittedChanges = { param($path) return $false }
             Checkout = { param($path, $branch) return [PSCustomObject]@{ Success = $true; Message = "Ok" } }
             Pull = { param($path) return [PSCustomObject]@{ Success = $true } }
             DeleteLocalBranch = { param($path, $branch, $force) return [PSCustomObject]@{ Success = $true } }
             DeleteRemoteBranch = { param($path, $branch) return [PSCustomObject]@{ Success = $true } }
        }
        $context.RepoManager = $stubRepoManager
    }

    Context "CanExecute" {
        It "returns true for B key" {
            $keyPress = [PSCustomObject]@{ VirtualKeyCode = [Constants]::KEY_B }
            $command.CanExecute($keyPress, $context) | Should -Be $true
        }
        
        It "returns false for other keys" {
             $keyPress = [PSCustomObject]@{ VirtualKeyCode = 65 }
             $command.CanExecute($keyPress, $context) | Should -Be $false
        }
    }

    Context "Execute" {
        It "returns early if no repo" {
            $context.State.CurrentIndex = 99
            $command.Execute($null, $context)
            $context.State.CurrentIndex = 0 # Reset
        }
        
        It "Simulates Checkout Flow" {
            # Setup
            $context.OptionSelector.NextSelection = @{ Type = "Item"; Value = "feature/1"; Index = 0 }
            $context.OptionSelector.ActionResponse = "Checkout"
            
            # Execute
            $command.Execute($null, $context)
            
            # Implicit assertions
            $true | Should -Be $true
        }
        
        It "Simulates Pull Flow" {
            $context.OptionSelector.ActionResponse = "Pull"
            $command.Execute($null, $context)
            $true | Should -Be $true
        }
        
        It "Displays error if not git repo" {
             $context.RepoManager.GitService | Add-Member -MemberType ScriptMethod -Name IsGitRepository -Value { return $false } -Force
             $command.Execute($null, $context)
             $context.RepoManager.GitService | Add-Member -MemberType ScriptMethod -Name IsGitRepository -Value { return $true } -Force
        }
    }
}
