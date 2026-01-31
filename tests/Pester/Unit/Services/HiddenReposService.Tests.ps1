# tests/Pester/Unit/Services/HiddenReposService.Tests.ps1

Describe "HiddenReposService" {
    BeforeAll {
        $srcRoot = Resolve-Path "$PSScriptRoot\..\..\..\..\src"
        $testRoot = Resolve-Path "$PSScriptRoot\..\..\.."
        
        # Load logic/interfaces
        . "$srcRoot\Services\ArrayHelper.ps1"
        . "$srcRoot\Core\Interfaces\IUserPreferencesService.ps1"
        . "$srcRoot\Core\Interfaces\IHiddenReposService.ps1"
        . "$srcRoot\Services\HiddenReposService.ps1"

        # Load centralized mocks
        . "$testRoot\Mocks\MockUserPreferencesService.ps1"
    }

    BeforeEach {
        # Initial Mock Data
        $prefs = [PSCustomObject]@{
            hidden = [PSCustomObject]@{
                hiddenRepos = @("Repo1", "Repo2")
            }
        }
        
        $script:mockService = [MockUserPreferencesService]::new($prefs)
        $script:service = [HiddenReposService]::new($script:mockService)
    }

    Context "Initial State" {
        It "Loads hidden repos from preferences" {
            $h = $script:service.GetHiddenList()
            $h | Should -Contain "Repo1"
            $h | Should -Contain "Repo2"
        }

        It "Initializes ShowHidden state" {
            $script:service.GetShowHiddenState() | Should -BeFalse
        }
    }

    Context "Visibility Logic" {
        It "Correctly identifies hidden repos" {
            $script:service.IsHidden("Repo1") | Should -BeTrue
            $script:service.IsHidden("Repo3") | Should -BeFalse
        }

        It "Hides a new repo" {
            $result = $script:service.AddToHidden("Repo3")
            $result | Should -BeTrue
            $script:service.IsHidden("Repo3") | Should -BeTrue
            
            # Verify Persistence in Mock
            $script:mockService.MockPrefs.hidden.hiddenRepos | Should -Contain "Repo3"
        }

        It "Unhides a repo" {
            $result = $script:service.RemoveFromHidden("Repo1")
            $result | Should -BeTrue
            $script:service.IsHidden("Repo1") | Should -BeFalse
        }
    }

    Context "Toggle Logic" {
        It "Toggles Visibility" {
            $script:service.ToggleShowHidden()
            $script:service.GetShowHiddenState() | Should -BeTrue
            
            $script:service.ToggleShowHidden()
            $script:service.GetShowHiddenState() | Should -BeFalse
        }
        
        It "SetShowHiddenState sets state correctly" {
            $script:service.SetShowHiddenState($true)
            $script:service.GetShowHiddenState() | Should -BeTrue
            
            $script:service.SetShowHiddenState($false)
            $script:service.GetShowHiddenState() | Should -BeFalse
        }
    }
    
    Context "Hidden Count" {
        It "Returns correct count of hidden repos" {
            $count = $script:service.GetHiddenCount()
            $count | Should -Be 2
        }
        
        It "Returns zero when no hidden repos" {
            $script:service.ClearAllHidden()
            $count = $script:service.GetHiddenCount()
            $count | Should -Be 0
        }
    }
    
    Context "Clear All Hidden" {
        It "Clears all hidden repositories" {
            $result = $script:service.ClearAllHidden()
            $result | Should -BeTrue
            $script:service.GetHiddenCount() | Should -Be 0
            $script:service.GetHiddenList() | Should -BeNullOrEmpty
        }
    }
    
    Context "Edge Cases" {
        It "AddToHidden returns false for null path" {
            $result = $script:service.AddToHidden($null)
            $result | Should -BeFalse
        }
        
        It "AddToHidden returns false for empty path" {
            $result = $script:service.AddToHidden("")
            $result | Should -BeFalse
        }
        
        It "AddToHidden returns false for whitespace path" {
            $result = $script:service.AddToHidden("   ")
            $result | Should -BeFalse
        }
        
        It "RemoveFromHidden returns false for null path" {
            $result = $script:service.RemoveFromHidden($null)
            $result | Should -BeFalse
        }
        
        It "RemoveFromHidden returns false for empty path" {
            $result = $script:service.RemoveFromHidden("")
            $result | Should -BeFalse
        }
        
        It "RemoveFromHidden returns false for whitespace path" {
            $result = $script:service.RemoveFromHidden("   ")
            $result | Should -BeFalse
        }
        
        It "AddToHidden returns true when repo already hidden" {
            $result = $script:service.AddToHidden("Repo1")
            $result | Should -BeTrue
            $script:service.GetHiddenCount() | Should -Be 2
        }
    }
    
    Context "Hidden Section Initialization" {
        It "Creates hidden section when missing" {
            $emptyPrefs = [PSCustomObject]@{}
            $mockServiceEmpty = [MockUserPreferencesService]::new($emptyPrefs)
            $serviceEmpty = [HiddenReposService]::new($mockServiceEmpty)
            
            $list = $serviceEmpty.GetHiddenList()
            $list | Should -BeNullOrEmpty
        }
        
        It "Creates hiddenRepos property when missing" {
            $prefsNoHiddenRepos = [PSCustomObject]@{
                hidden = [PSCustomObject]@{}
            }
            $mockServiceNoRepos = [MockUserPreferencesService]::new($prefsNoHiddenRepos)
            $serviceNoRepos = [HiddenReposService]::new($mockServiceNoRepos)
            
            $list = $serviceNoRepos.GetHiddenList()
            $list | Should -BeNullOrEmpty
        }
    }
}
