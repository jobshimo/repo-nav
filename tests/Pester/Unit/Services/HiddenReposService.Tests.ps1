# tests/Pester/Unit/Services/HiddenReposService.Tests.ps1

Describe "HiddenReposService" {
    BeforeAll {
        $srcRoot = Resolve-Path "$PSScriptRoot\..\..\..\..\src"
        . "$srcRoot\Services\ArrayHelper.ps1"
        . "$srcRoot\Core\Interfaces\IUserPreferencesService.ps1"
        . "$srcRoot\Core\Interfaces\IHiddenReposService.ps1"
        . "$srcRoot\Services\HiddenReposService.ps1"

        # Define Mock Class
        $mockClass = @"
        class MockPreferencesService : IUserPreferencesService {
            [PSCustomObject] `$MockPrefs
            [string] `$LastSection
            [string] `$LastKey
            [object] `$LastValue

            MockPreferencesService([PSCustomObject]`$prefs) {
                `$this.MockPrefs = `$prefs
            }

            [PSCustomObject] LoadPreferences() {
                return `$this.MockPrefs
            }

            [bool] SetPreference([string]`$section, [string]`$key, [object]`$value) {
                `$this.LastSection = `$section
                `$this.LastKey = `$key
                `$this.LastValue = `$value
                return `$true
            }

            [bool] SavePreferences([PSCustomObject]`$prefs) {
                `$this.MockPrefs = `$prefs
                return `$true
            }
        }
"@
        if (-not ("MockPreferencesService" -as [type])) {
            Invoke-Expression $mockClass
        }
    }

    BeforeEach {
        # Initial Mock Data
        $prefs = [PSCustomObject]@{
            hidden = [PSCustomObject]@{
                hiddenRepos = @("Repo1", "Repo2")
            }
        }
        
        $script:mockService = [MockPreferencesService]::new($prefs)
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
            
            # Verify "Persistence"
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
    }
}
