# tests/Pester/Unit/AliasManager.Tests.ps1

Describe "AliasManager" {
    BeforeAll {
        $srcRoot = Resolve-Path "$PSScriptRoot\..\..\..\src"
        $testRoot = Resolve-Path "$PSScriptRoot\..\..\.."
        . "$testRoot\tests\Test-Setup.ps1" | Out-Null
        
        # Ensure dependencies are loaded
        . "$srcRoot\Models\AliasInfo.ps1"
        . "$srcRoot\Config\ColorPalette.ps1"
        . "$srcRoot\Services\ConfigurationService.ps1"
        . "$srcRoot\Services\AliasManager.ps1"
    }

    BeforeEach {
        $tempFile = [System.IO.Path]::GetTempFileName()
        $configService = New-Object ConfigurationService -ArgumentList $tempFile
        $aliasManager = New-Object AliasManager -ArgumentList $configService
    }

    AfterEach {
        if (Test-Path $tempFile) {
            Remove-Item $tempFile -Force
        }
    }

    Context "Alias Management" {
        It "Starts with no aliases" {
            $aliasManager.GetAllAliases().Count | Should -Be 0
        }

        It "Sets and gets an alias" {
            $info = [AliasInfo]::new("MyAlias", [System.ConsoleColor]::Cyan)
            $aliasManager.SetAlias("C:\Repo", $info) | Should -BeTrue
            
            $aliasManager.HasAlias("C:\Repo") | Should -BeTrue
            $retrieved = $aliasManager.GetAlias("C:\Repo")
            $retrieved.Alias | Should -Be "MyAlias"
            $retrieved.Color | Should -Be ([System.ConsoleColor]::Cyan).ToString()
        }

        It "Removes an alias" {
            $info = [AliasInfo]::new("Alias", [System.ConsoleColor]::White)
            $aliasManager.SetAlias("C:\Repo", $info)
            $aliasManager.RemoveAlias("C:\Repo") | Should -BeTrue
            $aliasManager.HasAlias("C:\Repo") | Should -BeFalse
        }

        It "Handles legacy alias format (hashtable)" {
            $legacyJson = @{
                aliases = @{
                    "C:\Repo" = @{ alias = "Legacy"; color = "Green" }
                }
            } | ConvertTo-Json
            $legacyJson | Set-Content $tempFile -Encoding UTF8
            
            $aliasManager.HasAlias("C:\Repo") | Should -BeTrue
            $aliasManager.GetAlias("C:\Repo").Alias | Should -Be "Legacy"
        }
    }

    Context "Favorite Management" {
        It "Adds and removes favorites" {
            $aliasManager.AddFavorite("MyRepo") | Should -BeTrue
            $aliasManager.IsFavorite("MyRepo") | Should -BeTrue
            
            $aliasManager.RemoveFavorite("MyRepo") | Should -BeTrue
            $aliasManager.IsFavorite("MyRepo") | Should -BeFalse
        }

        It "Toggles favorites" {
            $aliasManager.IsFavorite("RepoX") | Should -BeFalse
            
            $aliasManager.ToggleFavorite("RepoX") | Should -BeTrue
            $aliasManager.IsFavorite("RepoX") | Should -BeTrue
            
            $aliasManager.ToggleFavorite("RepoX") | Should -BeTrue
            $aliasManager.IsFavorite("RepoX") | Should -BeFalse
        }

        It "Returns all favorites" {
            $aliasManager.AddFavorite("A")
            $aliasManager.AddFavorite("B")
            
            $favs = $aliasManager.GetFavorites()
            $favs | Should -Contain "A"
            $favs | Should -Contain "B"
            $favs.Count | Should -Be 2
        }
    }
}
