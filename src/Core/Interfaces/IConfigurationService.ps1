
# src/Core/Interfaces/IConfigurationService.ps1

class IConfigurationService {
    [PSCustomObject] LoadConfiguration() { return $null }
    [bool] SaveConfiguration([PSCustomObject]$config) { return $false }
    [PSCustomObject] CreateEmptyConfiguration() { return $null }
    [bool] ConfigurationExists() { return $false }
    [hashtable] GetConfigurationInfo() { return @{} }
}
