class IUserPreferencesService {
    [PSCustomObject] LoadPreferences() { return $null }
    [bool] SavePreferences([PSCustomObject]$preferences) { return $false }
    [PSCustomObject] CreateDefaultPreferences() { return $null }
    [bool] PreferencesExists() { return $false }
    [object] GetPreference([string]$section, [string]$key) { return $null }
    [bool] SetPreference([string]$section, [string]$key, [object]$value) { return $false }
    [bool] TogglePreference([string]$section, [string]$key) { return $false }
    [void] EnsurePathInPreferences([string]$path) {}
}
