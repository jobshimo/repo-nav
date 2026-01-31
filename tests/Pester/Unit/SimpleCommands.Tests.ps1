Describe "Simple Commands" {
    BeforeAll {
        $scriptRoot = Resolve-Path "$PSScriptRoot\..\..\.."
        $srcRoot = Join-Path $scriptRoot "src"
        
        # Use Test-Setup for reliable loading
        . "$scriptRoot\tests\Test-Setup.ps1" | Out-Null
    }

    # Helper function defined inside the test script to access the types defined above
    function New-MockCommandContext {
        $mockConsole = [ConsoleHelper]::new()
        
        $mockState = [NavigationState]::new(@())
        
        $mockRepoManager = [RepositoryManager]::new($null, $null, $null, $null, $null, $null, $null, $null, $null, $null, $null, $null, $null, $null)
        
        $mockHiddenService = [HiddenReposService]::new($null)
        
        # Create Context manually since constructor might not be available or we want control
        $context = [CommandContext]::new()
        $context.Console = $mockConsole
        $context.State = $mockState
        $context.RepoManager = $mockRepoManager
        $context.RepositoryManager = $mockRepoManager
        $context.HiddenReposService = $mockHiddenService
        
        return $context
    }

    Context "ExitCommand" {
        It "CanExecute returns true for Q, ESC and Quit Keys" {
            $cmd = [ExitCommand]::new()
            
            # Using Constants
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
        It "CanExecute returns true for V key" {
            $cmd = [ToggleHiddenVisibilityCommand]::new()
            $keyV = [PSCustomObject]@{ VirtualKeyCode = [Constants]::KEY_V }
            $cmd.CanExecute($keyV, $null) | Should -BeTrue
        }
        
        It "GetDescription returns correct text" {
            $cmd = [ToggleHiddenVisibilityCommand]::new()
            $cmd.GetDescription() | Should -Match "Toggle"
        }

        It "Execute calls ToggleShowHidden on HiddenReposService" {
            # Setup Mock Context Inline
            $mockConsole = [ConsoleHelper]::new()
            $mockState = [NavigationState]::new(@())
            $mockRepoManager = [RepositoryManager]::new($null, $null, $null, $null, $null, $null, $null, $null, $null, $null, $null, $null, $null, $null)
            $mockHiddenService = [HiddenReposService]::new($null)
            
            # Create Context manually
            $context = [CommandContext]::new()
            $context.Console = $mockConsole
            $context.State = $mockState
            $context.RepoManager = $mockRepoManager
            # Alias if needed by some commands, but Toggle uses HiddenReposService
            $context.HiddenReposService = $mockHiddenService
            
            # Setup Mock behavior tracking
            $context.HiddenReposService | Add-Member -MemberType NoteProperty -Name "ToggleCalled" -Value $false
            $context.HiddenReposService | Add-Member -MemberType ScriptMethod -Name "ToggleShowHidden" -Value { 
                $this.ToggleCalled = $true 
            } -Force

            # Mock RepoManager methods called during refresh
            $context.RepoManager | Add-Member -MemberType ScriptMethod -Name "LoadRepositories" -Value { } -Force
            $context.RepoManager | Add-Member -MemberType ScriptMethod -Name "GetRepositories" -Value { return @() } -Force
            
            # Mock State methods
            $context.State | Add-Member -MemberType ScriptMethod -Name "GetCurrentIndex" -Value { return 0 } -Force
            $context.State | Add-Member -MemberType ScriptMethod -Name "GetRepositories" -Value { return @() } -Force
            $context.State | Add-Member -MemberType ScriptMethod -Name "SetRepositories" -Value { param($r) } -Force
            $context.State | Add-Member -MemberType ScriptMethod -Name "SetCurrentIndex" -Value { param($i) } -Force
            $context.State | Add-Member -MemberType ScriptMethod -Name "MarkForListRedraw" -Value { } -Force
            $context.State | Add-Member -MemberType NoteProperty -Name "ViewportStart" -Value 0 -Force
            $context.State | Add-Member -MemberType NoteProperty -Name "PageSize" -Value 10 -Force

            $cmd = [ToggleHiddenVisibilityCommand]::new()
            $cmd.Execute($null, $context)

            $context.HiddenReposService.ToggleCalled | Should -BeTrue
        }
        
        It "Execute returns early when HiddenReposService is null" {
            $mockState = [NavigationState]::new(@())
            $context = [CommandContext]::new()
            $context.State = $mockState
            $context.HiddenReposService = $null
            
            $cmd = [ToggleHiddenVisibilityCommand]::new()
            { $cmd.Execute($null, $context) } | Should -Not -Throw
        }
        
        It "Execute handles null RepoManager gracefully" {
            $mockState = [NavigationState]::new(@())
            $mockHiddenService = [HiddenReposService]::new($null)
            
            $context = [CommandContext]::new()
            $context.State = $mockState
            $context.HiddenReposService = $mockHiddenService
            $context.RepoManager = $null
            
            $mockHiddenService | Add-Member -MemberType ScriptMethod -Name "ToggleShowHidden" -Value { } -Force
            $mockState | Add-Member -MemberType ScriptMethod -Name "MarkForListRedraw" -Value { } -Force
            
            $cmd = [ToggleHiddenVisibilityCommand]::new()
            { $cmd.Execute($null, $context) } | Should -Not -Throw
        }
        
        It "Execute restores selection when repo exists in updated list" {
            $mockConsole = [ConsoleHelper]::new()
            $mockState = [NavigationState]::new(@())
            $mockRepoManager = [RepositoryManager]::new($null, $null, $null, $null, $null, $null, $null, $null, $null, $null, $null, $null, $null, $null)
            $mockHiddenService = [HiddenReposService]::new($null)
            
            $repo1 = [RepositoryModel]::new([System.IO.DirectoryInfo]::new("C:\Repo1"))
            $repo2 = [RepositoryModel]::new([System.IO.DirectoryInfo]::new("C:\Repo2"))
            
            $context = [CommandContext]::new()
            $context.Console = $mockConsole
            $context.State = $mockState
            $context.RepoManager = $mockRepoManager
            $context.HiddenReposService = $mockHiddenService
            
            $mockHiddenService | Add-Member -MemberType ScriptMethod -Name "ToggleShowHidden" -Value { } -Force
            $mockRepoManager | Add-Member -MemberType ScriptMethod -Name "LoadRepositories" -Value { } -Force
            $mockRepoManager | Add-Member -MemberType ScriptMethod -Name "GetRepositories" -Value { return @($repo1, $repo2) } -Force
            
            $mockState | Add-Member -MemberType ScriptMethod -Name "GetCurrentIndex" -Value { return 1 } -Force
            $mockState | Add-Member -MemberType ScriptMethod -Name "GetRepositories" -Value { return @($repo1, $repo2) } -Force
            $mockState | Add-Member -MemberType ScriptMethod -Name "SetRepositories" -Value { param($r) } -Force
            $mockState | Add-Member -MemberType ScriptMethod -Name "SetCurrentIndex" -Value { param($i) $this._index = $i } -Force
            $mockState | Add-Member -MemberType ScriptMethod -Name "MarkForListRedraw" -Value { } -Force
            $mockState | Add-Member -MemberType NoteProperty -Name "ViewportStart" -Value 0 -Force
            $mockState | Add-Member -MemberType NoteProperty -Name "PageSize" -Value 10 -Force
            $mockState | Add-Member -MemberType NoteProperty -Name "_index" -Value 0 -Force
            
            $cmd = [ToggleHiddenVisibilityCommand]::new()
            $cmd.Execute($null, $context)
            
            $mockState._index | Should -Be 1
        }
        
        It "Execute calculates viewport correctly" {
            $mockConsole = [ConsoleHelper]::new()
            $mockState = [NavigationState]::new(@())
            $mockRepoManager = [RepositoryManager]::new($null, $null, $null, $null, $null, $null, $null, $null, $null, $null, $null, $null, $null, $null)
            $mockHiddenService = [HiddenReposService]::new($null)
            
            $repos = 1..20 | ForEach-Object {
                [RepositoryModel]::new([System.IO.DirectoryInfo]::new("C:\Repo$_"))
            }
            
            $context = [CommandContext]::new()
            $context.Console = $mockConsole
            $context.State = $mockState
            $context.RepoManager = $mockRepoManager
            $context.HiddenReposService = $mockHiddenService
            
            $mockHiddenService | Add-Member -MemberType ScriptMethod -Name "ToggleShowHidden" -Value { } -Force
            $mockRepoManager | Add-Member -MemberType ScriptMethod -Name "LoadRepositories" -Value { } -Force
            $mockRepoManager | Add-Member -MemberType ScriptMethod -Name "GetRepositories" -Value { return $repos } -Force
            
            $mockState | Add-Member -MemberType ScriptMethod -Name "GetCurrentIndex" -Value { return 10 } -Force
            $mockState | Add-Member -MemberType ScriptMethod -Name "GetRepositories" -Value { return $repos } -Force
            $mockState | Add-Member -MemberType ScriptMethod -Name "SetRepositories" -Value { param($r) } -Force
            $mockState | Add-Member -MemberType ScriptMethod -Name "SetCurrentIndex" -Value { param($i) } -Force
            $mockState | Add-Member -MemberType ScriptMethod -Name "MarkForListRedraw" -Value { } -Force
            $mockState | Add-Member -MemberType NoteProperty -Name "ViewportStart" -Value 0 -Force
            $mockState | Add-Member -MemberType NoteProperty -Name "PageSize" -Value 10 -Force
            
            $cmd = [ToggleHiddenVisibilityCommand]::new()
            $cmd.Execute($null, $context)
            
            $mockState.ViewportStart | Should -BeGreaterThan 0
        }
    }
}
