Describe "NpmCommand" {
    BeforeAll {
        $scriptRoot = $PSScriptRoot
        if (-not $scriptRoot) {
            $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
        }
        $projectRoot = (Resolve-Path "$scriptRoot\..\..\..").Path
        . "$projectRoot\tests\Test-Setup.ps1" | Out-Null
        
        # Load Mock Classes
        . "$projectRoot\tests\Mocks\MockNpmServices.ps1"
    }

    BeforeEach {
        [ServiceRegistry]::Reset()
        
        $mockNpm = [MockNpmService]::new()
        [ServiceRegistry]::Register('NpmService', $mockNpm)
        
        $mockJob = [MockJobServiceV10]::new()
        [ServiceRegistry]::Register('JobService', $mockJob)

        $context = [CommandContext]::new()
        $context.Console = [ConsoleHelper]::new() 
        $context.Renderer = [MockUIRenderer]::new()
        # NpmView writes directly to Host via Write-Host mostly, but also uses ConsoleHelper.
        # Validating output is hard with Write-Host. We assume it runs.
        
        # State setup
        $dirInfo = [System.IO.DirectoryInfo]::new("C:\Test\Repo")
        $repo = [RepositoryModel]::new($dirInfo)
        
        $state = [NavigationState]::new(@($repo))
        $context.State = $state
        $context.State.SetRepositories(@($repo))
        
        # Dummy localization
        $context.LocalizationService = [MockLocalizationService]::new()
        
        $command = [NpmCommand]::new()
    }

    Context "CanExecute" {
        It "Returns true for 'I' key" {
            $k = [PSCustomObject]@{ VirtualKeyCode = [Constants]::KEY_I }
            $command.CanExecute($k, $null) | Should -Be $true
        }
        It "Returns true for 'X' key" {
            $k = [PSCustomObject]@{ VirtualKeyCode = [Constants]::KEY_X }
            $command.CanExecute($k, $null) | Should -Be $true
        }
        It "Returns false for other keys" {
            $k = [PSCustomObject]@{ VirtualKeyCode = [Constants]::KEY_Q }
            $command.CanExecute($k, $null) | Should -Be $false
        }
    }

    Context "InvokeInstall (I Key)" {
        It "Calls Start-Process when npm is available" {
            # Mock Start-Process
            Mock Start-Process { 
                return [PSCustomObject]@{ ExitCode = 0 }
            }
            Mock Push-Location {}
            Mock Pop-Location {}
            
            $k = [PSCustomObject]@{ VirtualKeyCode = [Constants]::KEY_I }
            
            # Suppress Write-Host
            { $command.Execute($k, $context) } | Should -Not -Throw
            
            Assert-MockCalled Start-Process -Times 1
        }
    }

    Context "InvokeRemove (X Key)" {
        It "Starts a job when confirmed (Success)" {
            # Use MockOptionSelector which returns True
             $context.OptionSelector = [MockOptionSelectorV2]::new()
            
            $k = [PSCustomObject]@{ VirtualKeyCode = [Constants]::KEY_X }
            
            # Expect success
            { $command.Execute($k, $context) } | Should -Not -Throw
            
            $jobService = [ServiceRegistry]::Resolve('JobService')
            $jobService.LastScript | Should -Not -BeNullOrEmpty
            $jobService.LastArgs[0] | Should -Be "C:\Test\Repo"
        }
    }
}
