
# tests/Pester/Unit/UserPreferencesService.Tests.ps1
using module "..\..\TestHelper.psm1"

Describe "UserPreferencesService" {
    BeforeAll {
        $srcRoot = Resolve-Path "$PSScriptRoot\..\..\..\src"
        . "$srcRoot\Config\_index.ps1"
        [Constants]::Initialize("$srcRoot\..")
        . "$srcRoot\Models\_index.ps1"
        . "$srcRoot\Services\ArrayHelper.ps1" # Dependency
        . "$srcRoot\Startup\ServiceRegistry.ps1" # Used for logging error
        . "$srcRoot\Services\UserPreferencesService.ps1"
    }

    BeforeEach {
        # Create temp file
        $tempFile = [System.IO.Path]::GetTempFileName()
        $service = [UserPreferencesService]::new($tempFile)
    }

    AfterEach {
        if (Test-Path $tempFile) {
            Remove-Item $tempFile -Force
        }
    }

    It "CreateDefaultPreferences returns valid structure" {
        $prefs = $service.CreateDefaultPreferences()
        
        $prefs | Should -Not -BeNullOrEmpty
        $prefs.display.favoritesOnTop | Should -Be $true
        $prefs.general.language | Should -Be "en"
    }
    
    It "LoadPreferences returns defaults if file empty/missing" {
        $prefs = $service.LoadPreferences()
        
        $prefs.general.language | Should -Be "en"
    }
    
    It "SavePreferences writes to file" {
         $prefs = $service.CreateDefaultPreferences()
         $prefs.general.language = "fr"
         
         $service.SavePreferences($prefs) | Should -BeTrue
         
         # Verify content
         $content = Get-Content $tempFile -Raw | ConvertFrom-Json
         $content.general.language | Should -Be "fr"
    }
    
    It "SetPreference updates specific value" {
         $service.SetPreference("general", "language", "es") | Should -BeTrue
         
         $prefs = $service.LoadPreferences()
         $prefs.general.language | Should -Be "es"
    }
    
    It "TogglePreference toggles boolean" {
         # Default is true
         $service.GetPreference("display", "favoritesOnTop") | Should -BeTrue
         
         $service.TogglePreference("display", "favoritesOnTop") | Should -BeTrue
         
         $service.GetPreference("display", "favoritesOnTop") | Should -BeFalse
    }
}
