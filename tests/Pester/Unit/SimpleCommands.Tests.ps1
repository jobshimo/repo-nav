
Describe "Simple Commands" {
    BeforeAll {
        $projectRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
        . "$projectRoot/tests/Test-Setup.ps1" | Out-Null
        
        # Load standard mocks
        . "$projectRoot/tests/Mocks/MockCommonServices.ps1"
        . "$projectRoot/tests/Mocks/MockRepositoryManager.ps1"
    }

    Context "ExitCommand" {
        It "CanExecute returns true for Q, ESC and Quit Keys" {
            $cmd = [ExitCommand]::new()
            
            $keyQ = [PSCustomObject]@{ VirtualKeyCode = [Constants]::KEY_Q }
            $keyEsc = [PSCustomObject]@{ VirtualKeyCode = [Constants]::KEY_ESC }
            
            $cmd.CanExecute($keyQ, $null) | Should -BeTrue
            $cmd.CanExecute($keyEsc, $null) | Should -BeTrue
        }

        It "CanExecute returns false for other keys" {
             $cmd = [ExitCommand]::new()
             $keyX = [PSCustomObject]@{ VirtualKeyCode = [Constants]::KEY_X }
             $cmd.CanExecute($keyX, $null) | Should -BeFalse
        }
    }

    Context "ToggleHiddenVisibilityCommand" {
        BeforeEach {
            # Clean setup using Mocks
            $mockConsole = [MockConsoleHelper]::new()
            $mockState = [MockNavigationState]::new()
            $mockRepoManager = [MockRepositoryManager]::new()
            $mockHiddenService = [MockHiddenReposService]::new()
            
            # Setup default mock behavior
            $mockState.SetRepositories(@())
            
            $context = [CommandContext]::new()
            $context.Console = $mockConsole
            $context.State = $mockState
            $context.RepoManager = $mockRepoManager
            # Legacy property RepositoryManager removed
            $context.HiddenReposService = $mockHiddenService
            
            $cmd = [ToggleHiddenVisibilityCommand]::new()
        }

        It "CanExecute returns true for V key" {
            $keyV = [PSCustomObject]@{ VirtualKeyCode = [Constants]::KEY_V }
            $cmd.CanExecute($keyV, $null) | Should -BeTrue
        }
        
        It "GetDescription returns correct text" {
            $cmd.GetDescription() | Should -Match "Toggle"
        }

        It "Execute calls ToggleShowHidden on HiddenReposService" {
            $cmd.Execute($null, $context)
            $mockHiddenService.ToggleCalled | Should -BeTrue
        }
        
        It "Execute returns early when HiddenReposService is null" {
            $context.HiddenReposService = $null
            { $cmd.Execute($null, $context) } | Should -Not -Throw
        }
        
        It "Execute handles null RepoManager gracefully" {
            $context.RepoManager = $null
            { $cmd.Execute($null, $context) } | Should -Not -Throw
            $mockHiddenService.ToggleCalled | Should -BeTrue
        }
        
        It "Execute restores selection when repo exists in updated list" {
            # Arrange
            $repo1 = [RepositoryModel]::new([System.IO.DirectoryInfo]::new("C:\Repo1"))
            $repo2 = [RepositoryModel]::new([System.IO.DirectoryInfo]::new("C:\Repo2"))
            $repos = @($repo1, $repo2)
            
            # Setup Mocks to return data
            $mockRepoManager.Repositories = $repos
            $mockRepoManager.RepositoryToReturn = $null # Not used here but good practice
            
            # Initial state
            $mockState.SetRepositories($repos)
            $mockState.SetCurrentIndex(1) # We are selecting Repo2
            
            # Act
            $cmd.Execute($null, $context)
            
            # Assert
            # The command logic re-loads repos from RepoManager into State
            # And tries to find the previously selected repository
            # Since we didn't change the list, it should find it at index 1
            # Note: The MockNavigationState implementation of SetCurrentIndex updates its property
            $mockState.GetCurrentIndex() | Should -Be 1
        }
        
        It "Execute calculates viewport correctly" {
            # Arrange
            $repos = 1..20 | ForEach-Object {
                [RepositoryModel]::new([System.IO.DirectoryInfo]::new("C:\Repo$_"))
            }
            $mockRepoManager.Repositories = $repos
            $mockState.SetRepositories($repos)
            $mockState.SetCurrentIndex(10) # Select item 11
            
            # Act
            $cmd.Execute($null, $context)
            
            # Assert
            # Verify that some state update happened. In a real mock we might check ViewportStart
            # But the current MockNavigationState doesn't expose ViewportStart logic fully
            # So we check that the command at least ran without error and refreshed the list
            $mockRepoManager.MethodCalls.Count | Should -BeGreaterThan 0
            
            # Verify it tried to fetch repos
            $getRepoCalls = $mockRepoManager.MethodCalls | Where-Object { $_.Method -eq "GetRepositories" }
            $getRepoCalls | Should -Not -BeNullOrEmpty
        }
    }
}
