# tests/Pester/Unit/AliasManager.Tests.ps1

Describe "AliasManager" {
    BeforeAll {
        $srcRoot = Resolve-Path "$PSScriptRoot\..\..\..\src"
        $testRoot = Resolve-Path "$PSScriptRoot\..\..\.."
        . "$testRoot\tests\Test-Setup.ps1" | Out-Null
        
        # Ensure dependencies are loaded
        . "$srcRoot\Models\AliasInfo.ps1"
        . "$srcRoot\Config\ColorPalette.ps1"
        . "$srcRoot\Core\Interfaces\IConfigurationService.ps1"
        . "$srcRoot\Services\AliasManager.ps1"

        # Load Mock
        . "$testRoot\tests\Mocks\MockConfigurationService.ps1"
    }

    BeforeEach {
        $script:mockConfig = [MockConfigurationService]::new()
        $script:aliasManager = [AliasManager]::new($script:mockConfig)
    }

    Context "Alias Management" {
        It "Starts with no aliases" {
            $script:aliasManager.GetAllAliases().Count | Should -Be 0
        }

        It "Sets and gets an alias" {
            $info = [AliasInfo]::new("MyAlias", [System.ConsoleColor]::Cyan)
            $script:aliasManager.SetAlias("C:\Repo", $info) | Should -BeTrue
            
            $script:aliasManager.HasAlias("C:\Repo") | Should -BeTrue
            $retrieved = $script:aliasManager.GetAlias("C:\Repo")
            $retrieved.Alias | Should -Be "MyAlias"
            $retrieved.Color | Should -Be ([System.ConsoleColor]::Cyan).ToString()
        }

        It "Removes an alias" {
            $info = [AliasInfo]::new("Alias", [System.ConsoleColor]::White)
            $script:aliasManager.SetAlias("C:\Repo", $info)
            $script:aliasManager.RemoveAlias("C:\Repo") | Should -BeTrue
            $script:aliasManager.HasAlias("C:\Repo") | Should -BeFalse
        }

        It "Handles legacy alias format (hashtable)" {
            # Mock configuration state
            $legacyAliases = [PSCustomObject]@{
                "C:\Repo" = @{ alias = "Legacy"; color = "Green" }
            }
            $script:mockConfig.SetMockAliases($legacyAliases)
            
            $script:aliasManager.HasAlias("C:\Repo") | Should -BeTrue
            $script:aliasManager.GetAlias("C:\Repo").Alias | Should -Be "Legacy"
        }
    }

    Context "Favorite Management" {
        It "Adds and removes favorites" {
            $script:aliasManager.AddFavorite("MyRepo") | Should -BeTrue
            $script:aliasManager.IsFavorite("MyRepo") | Should -BeTrue
            
            $script:aliasManager.RemoveFavorite("MyRepo") | Should -BeTrue
            $script:aliasManager.IsFavorite("MyRepo") | Should -BeFalse
        }

        It "Toggles favorites" {
            $script:aliasManager.IsFavorite("RepoX") | Should -BeFalse
            
            $script:aliasManager.ToggleFavorite("RepoX") | Should -BeTrue
            $script:aliasManager.IsFavorite("RepoX") | Should -BeTrue
            
            $script:aliasManager.ToggleFavorite("RepoX") | Should -BeTrue
            $script:aliasManager.IsFavorite("RepoX") | Should -BeFalse
        }

        It "Returns all favorites" {
            $script:aliasManager.AddFavorite("A")
            $script:aliasManager.AddFavorite("B")
            
            $favs = $script:aliasManager.GetFavorites()
            $favs | Should -Contain "A"
            $favs | Should -Contain "B"
            $favs.Count | Should -Be 2
        }
    }
}
