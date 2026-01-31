
Describe "GitFlowCommand" {
    BeforeAll {
        $scriptRoot = $PSScriptRoot
        if (-not $scriptRoot) {
             # Fallback if PSScriptRoot is empty in this scope
             $scriptRoot = $PSScriptRoot 
             if (-not $scriptRoot) { $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path }
        }
        Write-Host "DEBUG: scriptRoot = '$scriptRoot'"
        
        $testRoot = (Resolve-Path "$scriptRoot/../../../..").Path
        Write-Host "DEBUG: testRoot = '$testRoot'"

        $setupPath = Join-Path $testRoot "tests\Test-Setup.ps1"
        Write-Host "DEBUG: Loading Test-Setup from: $setupPath"
        . $setupPath | Out-Null

        # 2. Define Mocks inheriting from Real Interfaces/Classes
        # We use Invoke-Expression to delay parsing until AFTER Test-Setup has loaded the base types.
        $mockDefinitions = @'
        class MockConsoleHelper : ConsoleHelper { 
            [void] WriteLineColored([string]$msg, [System.ConsoleColor]$color) {} 
            [void] ReadKey() {}
            [void] ClearScreen() {}
            [void] NewLine() {}
            [void] WriteColored([string]$msg, [System.ConsoleColor]$color) {}
            [void] HideCursor() {}
            [void] ShowCursor() {}
            [void] SetCursorPosition([int]$x, [int]$y) {}
            [void] WriteSeparator([string]$char, [int]$len, [System.ConsoleColor]$color) {}
        }

        class MockUIRenderer : IUIRenderer {
            [void] RenderHeader([string]$title) {}
            [void] RenderHeader([string]$title, [string]$subtitle) {}
            [void] RenderHeader([string]$title, [string]$subtitle, [string]$highlight) {}
            [bool] ShouldShowHeaders() { return $true }
        }

        class MockNavigationState : NavigationState {
            [int] $CurrentIndex = 0
            [array] $Repos = @()
            
            MockNavigationState() : base(@()) {}
            
            [array] GetRepositories() { return $this.Repos }
            [int] GetCurrentIndex() { return $this.CurrentIndex }
            [void] SetCurrentIndex([int]$index) { $this.CurrentIndex = $index }
            [void] Stop() {}
            [void] Resume() {}
            [void] MarkForFullRedraw() {}
        }

        class MockRepoManager : IRepositoryManager {
            [object] $GitService
            
            MockRepoManager() {}

            [object] GetGitService() { return $this.GitService }
            [void] Initialize([string]$path) {}
            [array] GetRepositories() { return @() }
            [void] Refresh([bool]$force) {}
            [void] RefreshSingle([string]$path) {}
            [RepositoryModel] GetRepository([string]$name) { return $null }
            [OperationResult] CloneRepository([string]$url, [string]$customName) { return $null }
            
            # Implementing abstract methods from IRepositoryManager
            [void] LoadRepositories() {}
            [void] LoadRepositories([string]$basePath) {}
            [void] LoadRepositories([string]$basePath, [bool]$forceReload) {}
            [void] LoadRepositoriesInternal([string]$basePath, [string]$parentPath) {}
            [void] LoadContainerRepositories([string]$containerPath, [string]$parentPath) {}
            [RepositoryModel] GetRepositoryByPath([string]$fullPath) { return $null }
            [array] GetAllRepositoriesRecursive([string]$rootPath) { return @() }
            [void] AddRepository([string]$path) {}
            [void] RemoveRepository([string]$path) {}
            [bool] IsRepository([string]$path) { return $false }
            [void] SortRepositories([string]$strategy) {}
            [GitStatusManager] GetStatusManager() { return $null }
            [PathManager] GetPathManager() { return $null }
            [OnboardingService] GetOnboardingService() { return $null }
        }
'@
        # Only invoke if types not already defined (to be safe within BeforeAll if run multiple times? Pester runs BeforeAll once per Discovery usually)
        if (-not ("MockConsoleHelper" -as [type])) {
            Invoke-Expression $mockDefinitions
        }

        # DEBUG: Check types again - REMOVED
        
        # Use New-Object to avoid parse-time type checking issues
        $command = New-Object GitFlowCommand
        $context = New-Object CommandContext
        
        # Wire up Mocks
        $context.Console = [MockConsoleHelper]::new()
        $context.Renderer = [MockUIRenderer]::new() # Using our new Interface implementation
        $context.OptionSelector = [OptionSelector]::new($context.Console, $context.Renderer) # Real selector with mocks
        $context.LocalizationService = [LocalizationService]::new()
        
        # Wire up State Mock
        $mockState = [MockNavigationState]::new()
        
        # Create Dummy Repo correctly (RepositoryModel requires DirectoryInfo)
        $dummyDir = [System.IO.DirectoryInfo]::new("C:\Repo1")
        $repo = [RepositoryModel]::new($dummyDir)
        # Manually ensure FullPath is what we expect if DirectoryInfo needs it to exist (it doesn't for new object in .NET)
        # $repo.Name is set from DirectoryInfo.Name
        
        $mockState.Repos = @($repo)
        $context.State = $mockState
        
        # Wire up RepoManager Mock
        $mockRepoManager = [MockRepoManager]::new()
        $mockRepoManager.GitService = [PSCustomObject]@{
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
        $context.RepoManager = $mockRepoManager
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
            # Setup - Using Pester Mocking for OptionSelector interaction if possible, 
            # OR relying on the fact that we can't easily mock interaction in a headless test 
            # without a more sophisticated MockOptionSelector.
            # For now, let's verify it doesn't crash.
            
            # To truly test Execute, we need to mock OptionSelector.ShowSelection to return "feature/1"
            # Since OptionSelector is a class, we can mock it too!
        }
    }
}
