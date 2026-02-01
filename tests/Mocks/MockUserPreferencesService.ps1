# tests/Mocks/MockUserPreferencesService.ps1
class MockUserPreferencesService : IUserPreferencesService {
    [UserPreferences] $Preferences

    MockUserPreferencesService() {
        $this.Preferences = [UserPreferences]::new()
        # Initialize sub-objects to avoid null reference exceptions in tests
        $this.Preferences.Repository = [RepositoryPreferences]::new()
        $this.Preferences.Display = [DisplayPreferences]::new()
        $this.Preferences.General = [GeneralPreferences]::new()
        $this.Preferences.Git = [GitPreferences]::new()
        $this.Preferences.Hidden = [HiddenPreferences]::new()
    }

    [UserPreferences] LoadPreferences() {
        return $this.Preferences
    }

    [bool] SavePreferences([UserPreferences]$preferences) {
        $this.Preferences = $preferences
        return $true
    }

    [UserPreferences] CreateDefaultPreferences() {
        return [UserPreferences]::new()
    }

    [bool] PreferencesExists() {
        return $true
    }

    [object] GetPreference([string]$section, [string]$key) {
        # Simple reflection or manual mapping if needed
        # For mocks, we usually just access property directly in test setup
        return $null
    }

    [bool] SetPreference([string]$section, [string]$key, [object]$value) {
        return $true
    }

    [bool] TogglePreference([string]$section, [string]$key) {
        return $true
    }

    [void] EnsurePathInPreferences([string]$path) {
        # No-op
    }
}
