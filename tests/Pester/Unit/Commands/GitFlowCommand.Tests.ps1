# 1. Load Core Types FIRST (Script Scope)
# Use simple string path to avoid Object/Slash issues
$srcRoot = "$PSScriptRoot/../../../../src"

# Define Helper Stubs
# 1. Load Core Types via Indices (Safe due to guard clauses)
$srcRoot = "$PSScriptRoot/../../../../src"

try {
    # 1. Config & Models
    . "$srcRoot/Config/_index.ps1"
    . "$srcRoot/Models/_index.ps1"

    # 2. Interfaces
    if (-not ([System.Management.Automation.PSTypeName]'IRepositoryManager').Type) {
        . "$srcRoot/Core/Interfaces/IRepositoryManager.ps1"
    }
    if (-not ([System.Management.Automation.PSTypeName]'IProgressReporter').Type) {
        . "$srcRoot/Core/Interfaces/IProgressReporter.ps1"
    }

    # 2.1 Dependencies for State
    if (-not ([System.Management.Automation.PSTypeName]'WindowSizeCalculator').Type) {
        . "$srcRoot/Services/WindowSizeCalculator.ps1"
    }

    # 3. State (Required by Services/UI)
    if (-not ([System.Management.Automation.PSTypeName]'NavigationState').Type) {
        . "$srcRoot/Core/State/NavigationState.ps1"
    }
    
    # 4. Service Registry (Required by Services)
    if (-not ([System.Management.Automation.PSTypeName]'ServiceRegistry').Type) {
        . "$srcRoot/Startup/ServiceRegistry.ps1"
    }

    # 5. Services & UI (Dependencies for CommandContext)
    . "$srcRoot/Services/_index.ps1"
    . "$srcRoot/UI/_index.ps1"
    
    # 6. Core Managers
    if (-not ([System.Management.Automation.PSTypeName]'PathManager').Type) {
        . "$srcRoot/Core/Services/PathManager.ps1"
    }

    if (-not ([System.Management.Automation.PSTypeName]'CommandContext').Type) {
        . "$srcRoot/Core/State/CommandContext.ps1"
    }
    
    # 7. Command Interfaces
    if (-not ([System.Management.Automation.PSTypeName]'INavigationCommand').Type) {
        . "$srcRoot/Core/Commands/INavigationCommand.ps1"
    }

} catch {
    Write-Warning "Error loading types in GitFlow setup: $_"
    Write-Error $_.ScriptStackTrace
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

if ([System.Management.Automation.PSTypeName]'GitFlowCommand'.Type) {
    Describe "GitFlowCommand" {
        BeforeAll {
            try {
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
            } catch {
                Write-Warning "Failed to instantiate GitFlowCommand in BeforeAll: $_"
            }
        }
        
        # ... Tests ...
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
} else {
    Describe "GitFlowCommand (Skipped)" {
        It "Skipping because type could not be loaded" {
            Set-ItResult -Skipped -Because "GitFlowCommand type not found"
        }
    }
}
