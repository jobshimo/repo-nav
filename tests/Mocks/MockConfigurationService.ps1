
# tests/Mocks/MockConfigurationService.ps1

class MockConfigurationService : ConfigurationService {
    [PSCustomObject] $MockConfig
    [bool] $SaveResult
    [int] $SaveCallCount
    
    MockConfigurationService() {
        # Call base constructor with dummy path
        # Note: PowerShell classes don't support explicit base constructor call like C# base(), 
        # but Default constructor is called automatically.
        # If ConfigurationService has parameterless ctor, it's fine. It does.
        
        $this.MockConfig = [PSCustomObject]@{
            aliases = [System.Collections.ArrayList]::new()
            favorites = @()
        }
        $this.SaveResult = $true
        $this.SaveCallCount = 0
    }
    
    [PSCustomObject] LoadConfiguration() {
        return $this.MockConfig
    }
    
    [bool] SaveConfiguration([PSCustomObject]$config) {
        $this.MockConfig = $config
        $this.SaveCallCount++
        return $this.SaveResult
    }
    
    [void] SetMockAliases([System.Collections.ArrayList]$aliases) {
        $this.MockConfig.aliases = $aliases
    }
}
