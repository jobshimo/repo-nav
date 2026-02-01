# tests/Pester/Unit/UserPreferencesService.Tests.ps1
using module "..\..\TestHelper.psm1"

Describe "UserPreferencesService" {
    BeforeAll {
        $srcRoot = Resolve-Path "$PSScriptRoot\..\..\..\src"
        $scriptRoot = $PSScriptRoot
        $testRoot = Resolve-Path "$scriptRoot\..\..\.."
        
        # Use Test-Setup for reliable loading
        . "$testRoot\tests\Test-Setup.ps1" | Out-Null
        
        # Explicitly load the service to ensure it's available (workaround for type missing error)
        . "$srcRoot\Services\UserPreferencesService.ps1"
        . "$srcRoot\Models\Preferences\UserPreferences.ps1"
        . "$srcRoot\Models\Preferences\RepositoryPreferences.ps1"
        . "$srcRoot\Models\Preferences\PathAlias.ps1"
    }

    BeforeEach {
        # Create temp file
        $tempFile = [System.IO.Path]::GetTempFileName()
        # Use New-Object to avoid parse-time type check failure
        $service = New-Object UserPreferencesService -ArgumentList $tempFile
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

    It "PreferencesExists returns true if file exists" {
         $service.PreferencesExists() | Should -BeTrue
         
         $noFileService = New-Object UserPreferencesService -ArgumentList "nonexistent.json"
         $noFileService.PreferencesExists() | Should -BeFalse
    }

    It "GetPreference returns null for missing section or key" {
         $service.GetPreference("nonexistent", "key") | Should -BeNull
         $service.GetPreference("general", "nonexistent") | Should -BeNull
    }

    Context "Normalization" {
         It "Normalizes partial preferences file on load" {
              # Create a file with only one property
              '{"display": {"favoritesOnTop": false}}' | Set-Content $tempFile -Encoding UTF8
              
              $prefs = $service.LoadPreferences()
              
              $prefs.display.favoritesOnTop | Should -BeFalse
              # Normalized properties should exist
              $prefs.general.language | Should -Be "en"
              $prefs.hidden.hiddenRepos.Count | Should -Be 0
         }

         It "Handles corrupted JSON gracefully by returning defaults" {
              "INVALID JSON" | Set-Content $tempFile -Encoding UTF8
              
              $prefs = $service.LoadPreferences()
              $prefs | Should -Not -BeNull
              $prefs.general.language | Should -Be "en"
         }
    }

    Context "EnsurePathInPreferences" {
         It "Adds valid path to preferences" {
              $tempDir = [System.IO.Path]::GetTempPath()
              $service.EnsurePathInPreferences($tempDir)
              
              $prefs = $service.LoadPreferences()
              $prefs.Repository.Paths | Should -Contain (Resolve-Path $tempDir).Path
         }

         It "Does not add duplicate paths" {
              $tempDir = [System.IO.Path]::GetTempPath()
              $service.EnsurePathInPreferences($tempDir)
              $service.EnsurePathInPreferences($tempDir)
              
              $prefs = $service.LoadPreferences()
              $prefs.Repository.Paths.Count | Should -Be 1
         }
    }

    Context "Strong Typing Mapping" {
         It "Maps Favorites correctly" {
              $json = '{"repository": {"favorites": ["RepoA", "RepoB"]}}'
              $json | Set-Content $tempFile -Encoding UTF8
              
              $prefs = $service.LoadPreferences()
              $prefs.Repository.Favorites | Should -Contain "RepoA"
              $prefs.Repository.Favorites.Count | Should -Be 2
         }

         It "Maps PathAliases correctly (Legacy and Object)" {
              $json = @'
{
    "repository": {
        "pathAliases": {
             "Path1": "Alias1",
             "Path2": { "Text": "Alias2", "Color": "Green" }
        }
    }
}
'@
              $json | Set-Content $tempFile -Encoding UTF8
              
              $prefs = $service.LoadPreferences()
              
              $aliases = $prefs.Repository.PathAliases
              $aliases.ContainsKey("Path1") | Should -BeTrue
              $aliases["Path1"].Text | Should -Be "Alias1"
              $aliases["Path1"].Color | Should -Be "Default"
              
              $aliases.ContainsKey("Path2") | Should -BeTrue
              $aliases["Path2"].Text | Should -Be "Alias2"
              $aliases["Path2"].Color | Should -Be "Green"
         }
    }
}
