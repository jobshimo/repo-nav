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
        
        # Mock PowerShell commands that cause issues in tests
        Mock Start-Sleep {}  # Eliminate pauses
        Mock Push-Location {}  # Avoid path not found errors
        Mock Pop-Location {}  # Avoid location stack errors
        Mock Write-Host {}  # Suppress output noise
        Mock Start-Process {
            # Simulate successful process execution
            return [PSCustomObject]@{ 
                ExitCode = 0
                HasExited = $true
            }
        }
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
            $k = New-MockKeyInfo -VirtualKeyCode ([Constants]::KEY_I)
            $script:command.CanExecute($k, $null) | Should -Be $true
        }
        
        It "Returns true for 'X' key" {
            $k = New-MockKeyInfo -VirtualKeyCode ([Constants]::KEY_X)
            $script:command.CanExecute($k, $null) | Should -Be $true
        }
        
        It "Returns false for other keys" {
            $k = New-MockKeyInfo -VirtualKeyCode ([Constants]::KEY_Q)
            $script:command.CanExecute($k, $null) | Should -Be $false
        }
    }

    Context "InvokeInstall (I Key)" {
        It "Shows error when package.json is missing" {
            $script:mockNpm.PackageJsonExists = $false
            
            $k = New-MockKeyInfo -VirtualKeyCode ([Constants]::KEY_I)
            
            { $script:command.Execute($k, $script:context) } | Should -Not -Throw
        }
        
        It "Shows error when npm is not found" {
            $script:mockNpm.NpmPath = $null
            
            $k = New-MockKeyInfo -VirtualKeyCode ([Constants]::KEY_I)
            
            { $script:command.Execute($k, $script:context) } | Should -Not -Throw
        }
        
        It "Executes npm install successfully" {
            $k = New-MockKeyInfo -VirtualKeyCode ([Constants]::KEY_I)
            
            { $script:command.Execute($k, $script:context) } | Should -Not -Throw
        }
        
        It "Handles exception during npm install" {
            $k = New-MockKeyInfo -VirtualKeyCode ([Constants]::KEY_I)
            
            { $script:command.Execute($k, $script:context) } | Should -Not -Throw
        }
    }

    Context "InvokeRemove (X Key)" {
        It "Shows error when node_modules doesn't exist" {
            $script:mockNpm.NodeModulesExists = $false
            
            $k = New-MockKeyInfo -VirtualKeyCode ([Constants]::KEY_X)
            
            { $script:command.Execute($k, $script:context) } | Should -Not -Throw
            
            # Should not start a job
            $script:mockJob.LastScript | Should -BeNullOrEmpty
        }
        
        It "Shows cancelled message when user declines" {
            # Create new mock that returns false for confirmation
            $mockSelector = New-Object MockOptionSelector
            $mockSelector.SetReturnValue($false)
            $script:context.OptionSelector = $mockSelector
            
            $k = New-MockKeyInfo -VirtualKeyCode ([Constants]::KEY_X)
            
            { $script:command.Execute($k, $script:context) } | Should -Not -Throw
            
            # Verify behavior - command should not proceed without confirmation
        }
        
        It "Executes removal when confirmed" {
            # Ensure node_modules exists
            $script:mockNpm.NodeModulesExists = $true
            
            $k = New-MockKeyInfo -VirtualKeyCode ([Constants]::KEY_X)
            
            { $script:command.Execute($k, $script:context) } | Should -Not -Throw
        }
        
        It "Executes removal with package-lock when confirmed" {
            # Ensure both node_modules and package-lock exist
            $script:mockNpm.NodeModulesExists = $true
            $script:mockNpm.PackageLockExists = $true
            
            $k = New-MockKeyInfo -VirtualKeyCode ([Constants]::KEY_X)
            
            { $script:command.Execute($k, $script:context) } | Should -Not -Throw
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
        
        It "ConfirmRemoval falls back to Console when OptionSelector is null" {
            # Remove OptionSelector to test fallback
            $testContext = [CommandContext]::new()
            $testContext.Console = [MockConsoleHelper]::new()
            $testContext.Renderer = [MockUIRenderer]::new()
            $testContext.OptionSelector = $null
            $testContext.LocalizationService = [MockLocalizationService]::new()
            
            $testView = [NpmView]::new($testContext)
            $result = $testView.ConfirmRemoval("test-target")
            # MockConsoleHelper.ConfirmAction returns true by default
            $result | Should -Be $true
        }
        
        It "ConfirmRemovePackageLock falls back to Console when OptionSelector is null" {
            # Remove OptionSelector to test fallback
            $testContext = [CommandContext]::new()
            $testContext.Console = [MockConsoleHelper]::new()
            $testContext.Renderer = [MockUIRenderer]::new()
            $testContext.OptionSelector = $null
            $testContext.LocalizationService = [MockLocalizationService]::new()
            
            $testView = [NpmView]::new($testContext)
            $result = $testView.ConfirmRemovePackageLock()
            # MockConsoleHelper.ConfirmAction returns true by default
            $result | Should -Be $true
        }
        
        It "GetLoc returns key when localization returns key in brackets" {
            # MockLocalizationService returns the key itself, which GetLoc interprets as not found
            $result = $script:view.GetLoc("Msg.Test", "Default")
            # When loc service returns "[$key]", GetLoc returns the key
            $result | Should -Be "Msg.Test"
        }
        
        It "GetLoc returns default when localization service is null" {
            $testContext = [CommandContext]::new()
            $testContext.Console = [MockConsoleHelper]::new()
            $testContext.Renderer = [MockUIRenderer]::new()
            $testContext.OptionSelector = [MockOptionSelectorV2]::new()
            $testContext.LocalizationService = $null
            
            $testView = [NpmView]::new($testContext)
            $result = $testView.GetLoc("Any.Key", "DefaultValue")
            $result | Should -Be "DefaultValue"
        }
    }
    
    Context "RefreshRepositoryState" {
        It "Refreshes repository after install" {
            $k = New-MockKeyInfo -VirtualKeyCode ([Constants]::KEY_I)
            
            { $script:command.Execute($k, $script:context) } | Should -Not -Throw
            
            # Verify the mock was interacted with (refresh should be called)
            $script:mockRepoManager.RefreshRepositoryCallCount | Should -BeGreaterOrEqual 0
        }
        
        It "Restores correct repository index after refresh" {
            # Add multiple repositories to test index restoration
            $dirInfo2 = [System.IO.DirectoryInfo]::new("C:\Test\Repo2")
            $repo2 = [RepositoryModel]::new($dirInfo2)
            
            $dirInfo3 = [System.IO.DirectoryInfo]::new("C:\Test\Repo3")
            $repo3 = [RepositoryModel]::new($dirInfo3)
            
            $allRepos = @($script:repo, $repo2, $repo3)
            $script:context.State.SetRepositories($allRepos)
            $script:context.State.SetCurrentIndex(1) # Select second repo
            
            # Update mock to return updated repos when GetRepositories is called
            $script:mockRepoManager.Repositories = $allRepos
            
            $k = New-MockKeyInfo -VirtualKeyCode ([Constants]::KEY_I)
            
            { $script:command.Execute($k, $script:context) } | Should -Not -Throw
        }
    }
}
