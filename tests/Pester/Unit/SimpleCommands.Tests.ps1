Describe "Simple Commands" {
    BeforeAll {
        $scriptRoot = Resolve-Path "$PSScriptRoot\..\..\.."
        $srcRoot = Join-Path $scriptRoot "src"
        
        # 1. Config
        . "$srcRoot\Config\_index.ps1"
        [Constants]::Initialize($scriptRoot)

        # 2. Models
        . "$srcRoot\Models\_index.ps1"

        # 3. Core Infrastructure & Services
        . "$srcRoot\Core\Interfaces\IProgressReporter.ps1"
        . "$srcRoot\Core\State\NavigationState.ps1"
        . "$srcRoot\Services\_index.ps1"
        
        # 4. UI
        . "$srcRoot\UI\_index.ps1"

        # 5. Core Managers
        . "$srcRoot\Core\Services\PathManager.ps1"
        . "$srcRoot\Core\RepositoryManager.ps1"

        # 6. State
        . "$srcRoot\Core\State\CommandContext.ps1"

        # 7. Commands
        . "$srcRoot\Core\Commands\INavigationCommand.ps1"
        . "$srcRoot\Core\Commands\ExitCommand.ps1"
        . "$srcRoot\Core\Commands\ToggleHiddenVisibilityCommand.ps1"
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
    }
}
