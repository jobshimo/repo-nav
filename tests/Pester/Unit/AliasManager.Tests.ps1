# tests/Pester/Unit/AliasManager.Tests.ps1

Describe "AliasManager" {
    BeforeAll {
        $srcRoot = Resolve-Path "$PSScriptRoot\..\..\..\src"
        $testRoot = Resolve-Path "$PSScriptRoot\..\..\.."
        . "$testRoot\tests\Test-Setup.ps1" | Out-Null
        
        # Dependencies
        . "$srcRoot\Models\AliasInfo.ps1"
        . "$srcRoot\Models\Preferences\PathAlias.ps1"
        . "$srcRoot\Models\Preferences\UserPreferences.ps1"
        . "$srcRoot\Models\Preferences\RepositoryPreferences.ps1"
        . "$srcRoot\Config\ColorPalette.ps1"
        . "$srcRoot\Core\Interfaces\IUserPreferencesService.ps1"
        . "$srcRoot\Core\Interfaces\IAliasManager.ps1"
        . "$srcRoot\Services\AliasManager.ps1"
        
        # Load Mock
        . "$testRoot\tests\Mocks\MockUserPreferencesService.ps1"
    }

    BeforeEach {
        # Mock IUserPreferencesService
        $script:mockPrefsService = [MockUserPreferencesService]::new()
        $script:prefs = $script:mockPrefsService.Preferences
        
        $script:aliasManager = [AliasManager]::new($script:mockPrefsService)
    }

    Context "Alias Management" {
        It "Starts with no aliases" {
            $script:aliasManager.GetAllAliases().Count | Should -Be 0
        }

        It "Sets and gets an alias" {
            $info = [AliasInfo]::new("MyAlias", [System.ConsoleColor]::Cyan)
            $script:aliasManager.SetAlias("C:\Repo", $info) | Should -BeTrue
            
            # Verify it was saved to prefs
            $script:prefs.Repository.PathAliases.ContainsKey("C:\Repo") | Should -BeTrue
            $savedAlias = $script:prefs.Repository.PathAliases["C:\Repo"]
            $savedAlias.Text | Should -Be "MyAlias"
            
            # Verify retrieving it
            $retrieved = $script:aliasManager.GetAlias("C:\Repo")
            $retrieved.Alias | Should -Be "MyAlias"
            $retrieved.Color | Should -Be ([System.ConsoleColor]::Cyan).ToString()
        }

        It "Removes an alias" {
            # Setup initial state
            $script:prefs.Repository.PathAliases["C:\Repo"] = [PathAlias]::new("Alias", "White")
            
            $script:aliasManager.RemoveAlias("C:\Repo") | Should -BeTrue
            $script:prefs.Repository.PathAliases.ContainsKey("C:\Repo") | Should -BeFalse
        }
        
        It "IsAliasNameTaken detects duplicates" {
             $script:prefs.Repository.PathAliases["Repo1"] = [PathAlias]::new("MyAlias", "Green")
             
             $script:aliasManager.IsAliasNameTaken("MyAlias") | Should -BeTrue
             $script:aliasManager.IsAliasNameTaken("OtherAlias") | Should -BeFalse
        }
    }
}
