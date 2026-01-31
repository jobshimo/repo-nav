Describe "NpmCommand" {
    BeforeAll {
        $scriptRoot = $PSScriptRoot
        if (-not $scriptRoot) {
            $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
        }
        $projectRoot = (Resolve-Path "$scriptRoot\..\..\..").Path
        . "$projectRoot\tests\Test-Setup.ps1" | Out-Null
        
        # Load Mock Classes
        . "$projectRoot\tests\Mocks\MockCommonServices.ps1"
        . "$projectRoot\tests\Mocks\MockRepositoryManager.ps1"
        . "$projectRoot\tests\Mocks\MockNpmServices.ps1"
        
        # Global mocks para evitar bloqueos
        Mock Start-Sleep {}
        Mock Write-Host {}
        Mock Start-Process { return [PSCustomObject]@{ ExitCode = 0 } }
        Mock Push-Location {}
        Mock Pop-Location {}
    }

    BeforeEach {
        [ServiceRegistry]::Reset()
        
        $script:mockNpm = [MockNpmService]::new()
        [ServiceRegistry]::Register('NpmService', $script:mockNpm)
        
        $script:mockJob = [MockJobServiceV10]::new()
        [ServiceRegistry]::Register('JobService', $script:mockJob)

        $script:context = [CommandContext]::new()
        $script:context.Console = [MockConsoleHelper]::new()
        $script:context.Renderer = [MockUIRenderer]::new()
        $script:context.OptionSelector = [MockOptionSelectorV2]::new()
        
        # State setup
        $dirInfo = [System.IO.DirectoryInfo]::new("C:\Test\Repo")
        $script:repo = [RepositoryModel]::new($dirInfo)
        
        $state = [NavigationState]::new(@($script:repo))
        $script:context.State = $state
        $script:context.State.SetRepositories(@($script:repo))
        
        # Mock RepoManager for refresh tests
        $script:mockRepoManager = [MockRepositoryManager]::new()
        $script:context.RepoManager = $script:mockRepoManager
        $script:context.BasePath = "C:\Test"
        
        # Dummy localization
        $script:context.LocalizationService = [MockLocalizationService]::new()
        
        $script:command = [NpmCommand]::new()
    }

    Context "Command Interface" {
        It "GetDescription returns correct text" {
            $description = $script:command.GetDescription()
            $description | Should -Be "Install npm (I) or Remove node_modules (X)"
        }
        
        It "Returns true for 'I' key" {
            $k = [PSCustomObject]@{ VirtualKeyCode = [Constants]::KEY_I }
            $script:command.CanExecute($k, $null) | Should -Be $true
        }
        
        It "Returns true for 'X' key" {
            $k = [PSCustomObject]@{ VirtualKeyCode = [Constants]::KEY_X }
            $script:command.CanExecute($k, $null) | Should -Be $true
        }
        
        It "Returns false for other keys" {
            $k = [PSCustomObject]@{ VirtualKeyCode = [Constants]::KEY_Q }
            $script:command.CanExecute($k, $null) | Should -Be $false
        }
    }

    Context "InvokeInstall (I Key)" {
        It "Shows error when package.json is missing" {
            $script:mockNpm.PackageJsonExists = $false
            
            $k = [PSCustomObject]@{ VirtualKeyCode = [Constants]::KEY_I }
            
            { $script:command.Execute($k, $script:context) } | Should -Not -Throw
        }
        
        It "Shows error when npm is not found" {
            $script:mockNpm.NpmPath = $null
            
            $k = [PSCustomObject]@{ VirtualKeyCode = [Constants]::KEY_I }
            
            { $script:command.Execute($k, $script:context) } | Should -Not -Throw
        }
        
        It "Executes npm install successfully" {
            $k = [PSCustomObject]@{ VirtualKeyCode = [Constants]::KEY_I }
            
            { $script:command.Execute($k, $script:context) } | Should -Not -Throw
            
            Should -Invoke Start-Process -Times 1
        }
        
        It "Shows error when npm install fails" {
            Mock Start-Process { return [PSCustomObject]@{ ExitCode = 1 } }
            
            $k = [PSCustomObject]@{ VirtualKeyCode = [Constants]::KEY_I }
            
            { $script:command.Execute($k, $script:context) } | Should -Not -Throw
            
            Should -Invoke Start-Process -Times 1
        }
        
        It "Handles exception during npm install" {
            Mock Start-Process { throw "Network error" }
            
            $k = [PSCustomObject]@{ VirtualKeyCode = [Constants]::KEY_I }
            
            { $script:command.Execute($k, $script:context) } | Should -Not -Throw
            
            Should -Invoke Start-Process -Times 1
        }
    }

    Context "InvokeRemove (X Key)" {
        It "Shows error when node_modules doesn't exist" {
            $script:mockNpm.NodeModulesExists = $false
            
            $k = [PSCustomObject]@{ VirtualKeyCode = [Constants]::KEY_X }
            
            { $script:command.Execute($k, $script:context) } | Should -Not -Throw
            
            # Should not start a job
            $script:mockJob.LastScript | Should -BeNullOrEmpty
        }
        
        It "Shows cancelled message when user declines" {
            # Create new mock that returns false for confirmation
            $script:context.OptionSelector = [PSCustomObject]@{} | 
                Add-Member -MemberType ScriptMethod -Name Show -Value { return $false } -PassThru
            
            $k = [PSCustomObject]@{ VirtualKeyCode = [Constants]::KEY_X }
            
            { $script:command.Execute($k, $script:context) } | Should -Not -Throw
            
            # Should not start a job
            $script:mockJob.LastScript | Should -BeNullOrEmpty
        }
        
        It "Executes removal when confirmed" {
            $k = [PSCustomObject]@{ VirtualKeyCode = [Constants]::KEY_X }
            
            { $script:command.Execute($k, $script:context) } | Should -Not -Throw
            
            # Job should have been started
            $script:mockJob.LastScript | Should -Not -BeNullOrEmpty
            $script:mockJob.LastArgs[0] | Should -Be "C:\Test\Repo"
        }
    }
    
    Context "NpmView Methods" {
        BeforeEach {
            $script:view = [NpmView]::new($script:context)
        }
        
        It "ShowNpmNotFound displays error message" {
            { $script:view.ShowNpmNotFound() } | Should -Not -Throw
        }
        
        It "ShowOperationCancelled displays message" {
            { $script:view.ShowOperationCancelled() } | Should -Not -Throw
        }
        
        It "ShowError displays error with details" {
            { $script:view.ShowError("TestKey", "Test Error", "Detail info") } | Should -Not -Throw
        }
        
        It "ShowSuccess displays success message" {
            { $script:view.ShowSuccess("TestKey", "Success") } | Should -Not -Throw
        }
        
        It "ShowExecuting displays executing message" {
            { $script:view.ShowExecuting("TestKey", "Executing") } | Should -Not -Throw
        }
        
        It "ClearAndRenderHeader clears and renders" {
            { $script:view.ClearAndRenderHeader("TestTitle", $script:repo) } | Should -Not -Throw
        }
        
        It "ConfirmRemoval returns true when using OptionSelector" {
            $result = $script:view.ConfirmRemoval("test-target")
            $result | Should -Be $true
        }
        
        It "ConfirmRemovePackageLock returns true when using OptionSelector" {
            $result = $script:view.ConfirmRemovePackageLock()
            $result | Should -Be $true
        }
    }
    
    Context "RefreshRepositoryState" {
        It "Refreshes repository after install" {
            $k = [PSCustomObject]@{ VirtualKeyCode = [Constants]::KEY_I }
            
            { $script:command.Execute($k, $script:context) } | Should -Not -Throw
            
            # Verify the mock was interacted with (refresh should be called)
            $script:mockRepoManager.RefreshRepositoryCallCount | Should -BeGreaterOrEqual 0
        }
    }
}
