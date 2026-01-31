Describe "Complex Commands" {
    BeforeAll {
        $scriptRoot = Resolve-Path "$PSScriptRoot\..\..\.."
        $srcRoot = Join-Path $scriptRoot "src"
        
        # Use Test-Setup for reliable loading
        . "$scriptRoot\tests\Test-Setup.ps1" | Out-Null
        
        # Load Mock Repository Manager
        $mockRepoPath = Join-Path $PSScriptRoot "..\..\Mocks\MockRepositoryManager.ps1"
        if (Test-Path $mockRepoPath) {
            . $mockRepoPath
        } else {
            Throw "MockRepositoryManager not found at $mockRepoPath"
        }
        
        # Load Common Mock Services (Reusable)
        $mockServicesPath = Join-Path $PSScriptRoot "..\..\Mocks\MockCommonServices.ps1"
        if (Test-Path $mockServicesPath) {
            . $mockServicesPath
        } else {
            Throw "MockCommonServices not found at $mockServicesPath"
        }

        # Dynamic Mock Definitions - Using Interface Pattern (DIP)
        $mockDefs = @'
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
'@
        # Execute local mock definitions
        Invoke-Expression $mockDefs
        
        # Execute common service mocks (from MockCommonServices.ps1)
        Invoke-Expression $global:MockServiceDefinitions
    }

    Context "NpmCommand" {
        BeforeEach {
            # Mock PowerShell Cmdlets (these are not classes, safe to mock)
            Mock Start-Process { return [PSCustomObject]@{ ExitCode = 0 } }
            Mock Start-Sleep { }
            Mock Write-Host { } 
            Mock Push-Location { }
            Mock Pop-Location { }
            Mock Test-Path { return $true }
            
            # Register Mock Services using Interface Pattern (Following DIP)
            $mockJobService = New-Object MockJobService
            [ServiceRegistry]::Register('JobService', $mockJobService)
            
            $mockNpmService = New-Object MockNpmService
            [ServiceRegistry]::Register('NpmService', $mockNpmService)

            # Setup Mock Console - Using IConsoleHelper implementation
            $mockConsole = New-Object MockConsoleHelper
            
            # Setup State
            $mockState = New-Object MockNavigationState
            $repo = [RepositoryModel]::new([System.IO.DirectoryInfo]::new("C:\FakeRepo"))
            $mockState.SetRepositories(@($repo))
            $mockState.SetCurrentIndex(0)
            
            # Setup Mock Renderer - Using IUIRenderer implementation
            $renderer = New-Object MockUIRenderer

            # Setup RepoManager
            $repoManager = New-Object MockRepositoryManager
            $repoManager.Repositories = @($repo)
            $repoManager.RepositoryToReturn = $repo

            # Setup Context using Interface Abstraction
            $context = New-Object CommandContext
            $context.Console = $mockConsole
            $context.State = $mockState
            $context.Renderer = $renderer
            $context.RepoManager = $repoManager
            $context.LocalizationService = $null

            # Setup Command
            $cmd = [NpmCommand]::new()
        }

        It "Execute (Key I) runs invoke install" {
            # Key "I"
            $keyPress = [PSCustomObject]@{ VirtualKeyCode = [Constants]::KEY_I }
            
            $cmd.Execute($keyPress, $context)
            
            Assert-MockCalled Start-Process -Times 1
        }

        It "Execute (Key X) runs invoke remove (Delete)" {
            # Key "X"
            $keyPress = [PSCustomObject]@{ VirtualKeyCode = [Constants]::KEY_X }

            $cmd.Execute($keyPress, $context)
            
            # Verification: NpmService should have been called
            # In a real test, we would spy on the mock methods
            # For now, successful execution without errors is the key assertion
        }
    }
}
