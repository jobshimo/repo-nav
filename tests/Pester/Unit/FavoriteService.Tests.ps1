# tests/Pester/Unit/FavoriteService.Tests.ps1

Describe "FavoriteService" {
    BeforeAll {
        $srcRoot = Resolve-Path "$PSScriptRoot\..\..\..\src"
        $scriptRoot = $PSScriptRoot
        $testRoot = Resolve-Path "$scriptRoot\..\..\.."
        
        . "$testRoot\tests\Test-Setup.ps1" | Out-Null
        
        # Dependencies
        . "$srcRoot\Models\Preferences\UserPreferences.ps1"
        . "$srcRoot\Models\Preferences\RepositoryPreferences.ps1"
        . "$srcRoot\Core\Interfaces\IUserPreferencesService.ps1"
        . "$srcRoot\Core\Interfaces\IFavoriteService.ps1"
        . "$srcRoot\Services\FavoriteService.ps1"
        
        # Load Mock
        . "$testRoot\tests\Mocks\MockUserPreferencesService.ps1"
    }

    BeforeEach {
        # Mock IUserPreferencesService
        $script:mockPrefsService = [MockUserPreferencesService]::new()
        $script:prefs = $script:mockPrefsService.Preferences
        
        $script:favoriteService = [FavoriteService]::new($script:mockPrefsService)
    }

    It "Starts emptiness" {
        $script:favoriteService.GetFavorites().Count | Should -Be 0
    }

    It "Adds a favorite" {
        $script:favoriteService.AddFavorite("Repo1") | Should -BeTrue
        
        $script:prefs.Repository.Favorites | Should -Contain "Repo1"
        $script:favoriteService.IsFavorite("Repo1") | Should -BeTrue
    }

    It "Removes a favorite" {
        $script:prefs.Repository.Favorites = @("Repo1")
        
        $script:favoriteService.RemoveFavorite("Repo1") | Should -BeTrue
        
        $script:prefs.Repository.Favorites | Should -Not -Contain "Repo1"
        $script:favoriteService.IsFavorite("Repo1") | Should -BeFalse
    }

    It "Toggles a favorite" {
        $script:favoriteService.ToggleFavorite("Repo1") | Should -BeTrue
        $script:favoriteService.IsFavorite("Repo1") | Should -BeTrue
        
        $script:favoriteService.ToggleFavorite("Repo1") | Should -BeTrue
        $script:favoriteService.IsFavorite("Repo1") | Should -BeFalse
    }

    It "Clears all favorites" {
        $script:prefs.Repository.Favorites = @("A", "B")
        
        $script:favoriteService.ClearAllFavorites() | Should -BeTrue
        
        $script:prefs.Repository.Favorites.Count | Should -Be 0
    }
}
