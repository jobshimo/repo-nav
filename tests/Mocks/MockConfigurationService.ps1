
# tests/Mocks/MockConfigurationService.ps1

class MockConfigurationService : IConfigurationService {
    [PSCustomObject] $MockConfig
    [bool] $SaveResult
    [int] $SaveCallCount
    
    MockConfigurationService() {
        $this.MockConfig = [PSCustomObject]@{
            aliases = [PSCustomObject]@{}
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

    [bool] ConfigurationExists() {
        return $true
    }

    [PSCustomObject] CreateEmptyConfiguration() {
        return [PSCustomObject]@{
            aliases = [PSCustomObject]@{}
            favorites = @()
        }
    }

    [hashtable] GetConfigurationInfo() {
        return @{
            Exists = $true
            Path = "MOCK_PATH"
            Size = 100
            LastModified = [DateTime]::Now
        }
    }
    
    # Helper for tests
    [void] SetMockAliases([PSCustomObject]$aliases) {
        $this.MockConfig.aliases = $aliases
    }
}
