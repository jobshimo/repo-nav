
# tests/Mocks/MockUserPreferencesService.ps1

class MockUserPreferencesService : IUserPreferencesService {
    [PSCustomObject] $MockPrefs
    
    MockUserPreferencesService([PSCustomObject]$prefs) {
        $this.MockPrefs = $prefs
    }
    
    MockUserPreferencesService() {
        $this.MockPrefs = [PSCustomObject]@{
            hidden = [PSCustomObject]@{
                hiddenRepos = @()
            }
            display = [PSCustomObject]@{
                favoritesOnTop = $false
            }
        }
    }

    [PSCustomObject] LoadPreferences() {
        return $this.MockPrefs
    }

    [bool] SavePreferences([PSCustomObject]$prefs) {
        $this.MockPrefs = $prefs
        return $true
    }

    [object] GetPreference([string]$section, [string]$key) {
        if ($this.MockPrefs.PSObject.Properties.Name -contains $section -and 
            $this.MockPrefs.$section.PSObject.Properties.Name -contains $key) {
            return $this.MockPrefs.$section.$key
        }
        return $null
    }

    [bool] SetPreference([string]$section, [string]$key, [object]$value) {
        if (-not ($this.MockPrefs.PSObject.Properties.Name -contains $section)) {
            $this.MockPrefs | Add-Member -NotePropertyName $section -NotePropertyValue ([PSCustomObject]@{}) -Force
        }
        $this.MockPrefs.$section | Add-Member -NotePropertyName $key -NotePropertyValue $value -Force
        return $true
    }

    [bool] PreferencesExists() { return $true }
    [PSCustomObject] CreateDefaultPreferences() { return $this.MockPrefs }
    [bool] TogglePreference([string]$section, [string]$key) { return $true }
    [void] EnsurePathInPreferences([string]$path) {}
}
