# tests/Mocks/MockUserPreferencesService.ps1
class MockUserPreferencesService : IUserPreferencesService {
    [UserPreferences] $Preferences
    [hashtable] $KeyValueStore

    MockUserPreferencesService() {
        $this.Preferences = [UserPreferences]::new()
        $this.KeyValueStore = @{}
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
        $fullKey = "$section.$key"
        if ($this.KeyValueStore.ContainsKey($fullKey)) {
            return $this.KeyValueStore[$fullKey]
        }
        return $null
    }

    [bool] SetPreference([string]$section, [string]$key, [object]$value) {
        $fullKey = "$section.$key"
        $this.KeyValueStore[$fullKey] = $value
        return $true
    }

    [bool] TogglePreference([string]$section, [string]$key) {
        return $true
    }

    [void] EnsurePathInPreferences([string]$path) {
        # No-op
    }
}
