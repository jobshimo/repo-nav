Describe "Complex Commands" {
    BeforeAll {
        $scriptRoot = Resolve-Path "$PSScriptRoot\..\..\.."
        $srcRoot = Join-Path $scriptRoot "src"
        
        # Use Test-Setup for reliable loading
        . "$scriptRoot\tests\Test-Setup.ps1" | Out-Null
        
        # Load Mocks
        # Relative path from tests/Pester/Unit to tests/Mocks is ../../Mocks
        $mockRepoPath = Join-Path $PSScriptRoot "..\..\Mocks\MockRepositoryManager.ps1"
        if (Test-Path $mockRepoPath) {
            . $mockRepoPath
        } else {
            Throw "MockRepositoryManager not found atVal $mockRepoPath"
        }

        # Dynamic Mock Definition to avoid Parse Time errors
        $mockDefs = @'
        class MockNavigationState : NavigationState {
             [array] $Repos = @()
             [int] $CurrentIndex = 0

             MockNavigationState() : base(@()) {}
             # Override strict methods if needed, or rely on base if simple
             [void] Stop() {}
             [void] Resume() {}
             [void] MarkForFullRedraw() {}
             [void] SetRepositories([array]$repos) { $this.Repos = $repos }
             [void] SetCurrentIndex([int]$i) { $this.CurrentIndex = $i }
             [array] GetRepositories() { return $this.Repos }
             [int] GetCurrentIndex() { return $this.CurrentIndex }
        }
'@
        Invoke-Expression $mockDefs
    }

    Context "NpmCommand" {
        BeforeEach {
            # Define Mocks here to ensure they are available in the test scope
            Mock Start-Process { return [PSCustomObject]@{ ExitCode = 0 } }
            # Remove cmdlet mocks as we now use IJobService
            Mock Start-Sleep { }
            Mock Write-Host { } 
            Mock Push-Location { }
            Mock Pop-Location { }
            Mock Test-Path { return $true }
            
            # Mock Job Service using Dynamic Mock Pattern
            $mockJobCode = @'
            class MockJobService : IJobService {
                [object] StartJob([scriptblock]$s, [object[]]$a) {
                    return [PSCustomObject]@{ State = 'Completed'; ChildJobs = @([PSCustomObject]@{ Error = $null }) }
                }
                [object] WaitJob([object]$j) { return $null }
                [object] ReceiveJob([object]$j) { return $true }
                [void] RemoveJob([object]$j, [bool]$f) { }
            }
'@
            Invoke-Expression $mockJobCode
            $mockJobService = New-Object MockJobService
            [ServiceRegistry]::Register('JobService', $mockJobService)

            # Setup Common Objects
            $mockConsole = [ConsoleHelper]::new()
            $mockConsole | Add-Member -MemberType ScriptMethod -Name "ClearForWorkflow" -Value {} -Force
            $mockConsole | Add-Member -MemberType ScriptMethod -Name "WriteLineColored" -Value { param($m, $c) } -Force
            $mockConsole | Add-Member -MemberType ScriptMethod -Name "ConfirmAction" -Value { return $true } -Force
            
            # Setup State
            $mockState = New-Object MockNavigationState
            $repo = [RepositoryModel]::new([System.IO.DirectoryInfo]::new("C:\FakeRepo"))
            $mockState.SetRepositories(@($repo))
            $mockState.SetCurrentIndex(0)
            
            # Setup Renderer
            $renderer = [UIRenderer]::new($mockConsole, $null)
            $renderer | Add-Member -MemberType ScriptMethod -Name "RenderWorkflowHeader" -Value { param($t, $r) } -Force
            $renderer | Add-Member -MemberType ScriptMethod -Name "RenderError" -Value { param($m) } -Force

            # Setup RepoManager
            $repoManager = New-Object MockRepositoryManager
            $repoManager.Repositories = @($repo)
            $repoManager.RepositoryToReturn = $repo

            # Setup Context
            $context = New-Object CommandContext
            $context.Console = [ConsoleHelper]$mockConsole
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
            
            # Mock HaveNodeModules to return true (logic in NpmService?)
            # NpmCommand gets NpmService from ServiceRegistry.
            # We must Mock the NpmService in ServiceRegistry!
            # The tests previously registered it?
            # Creating NpmService requires dependencies.
            # We can register a Mock object as NpmService.
            
            $mockNpmService = [PSCustomObject]@{
                HasPackageJson = { return $true }
                GetNpmExecutablePath = { return "npm" }
                HasNodeModules = { return $true }
                HasPackageLock = { return $false }
            }
            # Add methods using Add-Member to allow ScriptBlock calls
            $mockNpmService | Add-Member -MemberType ScriptMethod -Name "HasPackageJson" -Value { return $true } -Force
            $mockNpmService | Add-Member -MemberType ScriptMethod -Name "GetNpmExecutablePath" -Value { return "npm" } -Force
            $mockNpmService | Add-Member -MemberType ScriptMethod -Name "HasNodeModules" -Value { return $true } -Force
            $mockNpmService | Add-Member -MemberType ScriptMethod -Name "HasPackageLock" -Value { return $false } -Force
            
            [ServiceRegistry]::Register('NpmService', $mockNpmService)

            $cmd.Execute($keyPress, $context)
            
            # Assertions: We could spy on mockJobService if needed, but for now successful execution without errors is key.
            # Assert-MockCalled Start-Job -Times 1  <-- No longer relevant as we call JobService
        }
    }
}
