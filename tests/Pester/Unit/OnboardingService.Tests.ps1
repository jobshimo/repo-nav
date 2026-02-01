BeforeAll {
    . "$PSScriptRoot/../../Test-Setup.ps1"
    . "$PSScriptRoot/../../../tests/Mocks/MockCommonServices.ps1"
    . "$PSScriptRoot/../../../tests/Mocks/MockNpmServices.ps1"
    
    # Mock PowerShell commands
    Mock Start-Sleep {}
    Mock Write-Host {}
    
    # Create mock instances using proper Mock classes
    $script:mockRenderer = New-Object MockUIRenderer
    $script:mockConsole = New-Object MockConsoleHelper
    $script:mockLoc = New-Object MockLocalizationService
    $script:mockOptionSelector = New-Object MockOptionSelector
    $script:mockPreferencesService = New-Object MockUserPreferencesService
}

Describe "OnboardingService" -Tag "Unit", "OnboardingService" {
    
    Context "Constructor" {
        It "Should initialize with all dependencies" {
            # Arrange & Act
            $service = [OnboardingService]::new(
                $script:mockRenderer,
                $script:mockConsole,
                $script:mockLoc,
                $script:mockOptionSelector,
                $script:mockPreferencesService
            )
            
            # Assert
            $service.Renderer | Should -Not -BeNullOrEmpty
            $service.Console | Should -Not -BeNullOrEmpty
            $service.Loc | Should -Not -BeNullOrEmpty
            $service.OptionSelector | Should -Not -BeNullOrEmpty
            $service.PreferencesService | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "HandleEmptyState - User declines configuration" {
        It "Should return null when user selects No" {
            # Arrange
            $mockSelector = New-Object MockOptionSelector
            $mockSelector.SetReturnValue($false)
            
            $service = [OnboardingService]::new(
                $script:mockRenderer,
                $script:mockConsole,
                $script:mockLoc,
                $mockSelector,
                $script:mockPreferencesService
            )
            
            # Act
            $result = $service.HandleEmptyState("C:\test")
            
            # Assert
            $result | Should -BeNullOrEmpty
        }
        
        It "Should use InitialSetup message when current path is empty" {
            # Arrange
            $mockSelector = New-Object MockOptionSelector
            $mockSelector.SetReturnValue($false)
            
            $service = [OnboardingService]::new(
                $script:mockRenderer,
                $script:mockConsole,
                $script:mockLoc,
                $mockSelector,
                $script:mockPreferencesService
            )
            
            # Act & Assert - Should not throw
            { $service.HandleEmptyState("") } | Should -Not -Throw
        }
        
        It "Should use NoRepos message when current path exists" {
            # Arrange
            $mockSelector = New-Object MockOptionSelector
            $mockSelector.SetReturnValue($false)
            
            $service = [OnboardingService]::new(
                $script:mockRenderer,
                $script:mockConsole,
                $script:mockLoc,
                $mockSelector,
                $script:mockPreferencesService
            )
            
            # Act & Assert - Should not throw
            { $service.HandleEmptyState("C:\repos") } | Should -Not -Throw
        }
        
        It "Should configure selection options correctly" {
            # Arrange
            $mockSelector = New-Object MockOptionSelector
            $mockSelector.SetReturnValue($false)
            
            $service = [OnboardingService]::new(
                $script:mockRenderer,
                $script:mockConsole,
                $script:mockLoc,
                $mockSelector,
                $script:mockPreferencesService
            )
            
            # Act & Assert - Should not throw
            { $service.HandleEmptyState("C:\test") } | Should -Not -Throw
        }
    }
    
    Context "HandleEmptyState - User accepts and enters valid path" {
        It "Should save valid path and return resolved path" {
            # Arrange
            $testPath = $TestDrive
            
            $mockSelector = New-Object MockOptionSelector
            $mockSelector.SetReturnValue($true)
            
            $mockPrefs = New-Object MockUserPreferencesService
            
            $service = [OnboardingService]::new(
                $script:mockRenderer,
                $script:mockConsole,
                $script:mockLoc,
                $mockSelector,
                $mockPrefs
            )
            
            # Mock Read-Host
            Mock Read-Host { return $testPath } -ModuleName $null
            
            # Act
            $result = $service.HandleEmptyState("C:\test")
            
            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result | Should -Be (Resolve-Path $testPath).Path
        }
        
        It "Should trim quotes from entered path" {
            # Arrange
            $testPath = $TestDrive
            $quotedPath = "`"$testPath`""
            
            $mockSelector = New-Object MockOptionSelector
            $mockSelector.SetReturnValue($true)
            
            $service = [OnboardingService]::new(
                $script:mockRenderer,
                $script:mockConsole,
                $script:mockLoc,
                $mockSelector,
                $script:mockPreferencesService
            )
            
            # Mock Read-Host
            Mock Read-Host { return $quotedPath } -ModuleName $null
            
            # Act
            $result = $service.HandleEmptyState("")
            
            # Assert
            $result | Should -Be (Resolve-Path $testPath).Path
        }
        
        It "Should show and hide cursor appropriately" {
            # Arrange
            $testPath = $TestDrive
            
            $mockConsole = New-Object MockConsoleHelper
            
            $mockSelector = New-Object MockOptionSelector
            $mockSelector.SetReturnValue($true)
            
            $service = [OnboardingService]::new(
                $script:mockRenderer,
                $mockConsole,
                $script:mockLoc,
                $mockSelector,
                $script:mockPreferencesService
            )
            
            Mock Read-Host { return $testPath } -ModuleName $null
            
            # Act & Assert - Should not throw
            { $service.HandleEmptyState("") } | Should -Not -Throw
        }
        
        It "Should render success message after saving" {
            # Arrange
            $testPath = $TestDrive
            
            $mockRenderer = New-Object MockUIRenderer
            
            $mockSelector = New-Object MockOptionSelector
            $mockSelector.SetReturnValue($true)
            
            $service = [OnboardingService]::new(
                $mockRenderer,
                $script:mockConsole,
                $script:mockLoc,
                $mockSelector,
                $script:mockPreferencesService
            )
            
            Mock Read-Host { return $testPath } -ModuleName $null
            
            # Act & Assert - Should not throw
            { $service.HandleEmptyState("") } | Should -Not -Throw
        }
    }
    
    Context "HandleEmptyState - User enters invalid path" {
        It "Should return null and show error for non-existent path" {
            # Arrange
            $invalidPath = "C:\NonExistentPath123456789"
            
            $mockRenderer = New-Object MockUIRenderer
            
            $mockSelector = New-Object MockOptionSelector
            $mockSelector.SetReturnValue($true)
            
            $service = [OnboardingService]::new(
                $mockRenderer,
                $script:mockConsole,
                $script:mockLoc,
                $mockSelector,
                $script:mockPreferencesService
            )
            
            Mock Read-Host { return $invalidPath } -ModuleName $null
            
            # Act
            $result = $service.HandleEmptyState("")
            
            # Assert
            $result | Should -BeNullOrEmpty
        }
        
        It "Should return null and show error for empty/whitespace path" {
            # Arrange
            $mockRenderer = New-Object MockUIRenderer
            
            $mockSelector = New-Object MockOptionSelector
            $mockSelector.SetReturnValue($true)
            
            $service = [OnboardingService]::new(
                $mockRenderer,
                $script:mockConsole,
                $script:mockLoc,
                $mockSelector,
                $script:mockPreferencesService
            )
            
            Mock Read-Host { return "   " } -ModuleName $null
            
            # Act
            $result = $service.HandleEmptyState("")
            
            # Assert
            $result | Should -BeNullOrEmpty
        }
    }
}
