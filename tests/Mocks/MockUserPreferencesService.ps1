
# tests/Mocks/MockUserPreferencesService.ps1

class MockUserPreferencesService : UserPreferencesService {
    [hashtable] $MockPreferences
    
    MockUserPreferencesService() {
        $this.MockPreferences = @{}
    }
    
    [object] GetPreference([string]$category, [string]$key) {
        $fullKey = "$category.$key"
        if ($this.MockPreferences.ContainsKey($fullKey)) {
            return $this.MockPreferences[$fullKey]
        }
        return $null
    }
    
    # Helper to set preference
    [void] SetMockPreference([string]$category, [string]$key, [object]$value) {
        $fullKey = "$category.$key"
        $this.MockPreferences[$fullKey] = $value
    }
}
