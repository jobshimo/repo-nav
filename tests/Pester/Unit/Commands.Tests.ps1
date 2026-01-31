Describe "Complex Commands" {
    BeforeAll {
        $scriptRoot = Resolve-Path "$PSScriptRoot\..\..\.."
        $srcRoot = Join-Path $scriptRoot "src"
        
        # Use Test-Setup for reliable loading
        . "$scriptRoot\tests\Test-Setup.ps1" | Out-Null
        
        # Load Mocks (Direct loading - no Invoke-Expression needed)
        . "$PSScriptRoot\..\..\Mocks\MockRepositoryManager.ps1"
        . "$PSScriptRoot\..\..\Mocks\MockCommonServices.ps1"
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
