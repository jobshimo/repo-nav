<#
.SYNOPSIS
    ConfigurationService - Handles JSON configuration persistence
    
.DESCRIPTION
    Following SOLID principles:
    - SRP: Only responsible for reading/writing JSON configuration
    - DIP: Other classes depend on this abstraction for persistence
    - OCP: Can be extended for different file formats without modification
    
    This service manages the .repo-aliases.json file that contains:
    - Repository aliases
    - Favorite repositories
#>

class ConfigurationService {
    [string] $ConfigFilePath
    
    # Constructor
    ConfigurationService() {
        $this.ConfigFilePath = [Constants]::GetAliasFilePath()
    }
    
    # Constructor with custom path (for testing)
    ConfigurationService([string]$customPath) {
        $this.ConfigFilePath = $customPath
    }
    
    # Load configuration from file
    [PSCustomObject] LoadConfiguration() {
        if (-not (Test-Path $this.ConfigFilePath)) {
            return $this.CreateEmptyConfiguration()
        }
        
        try {
            $content = Get-Content $this.ConfigFilePath -Raw -ErrorAction Stop
            $config = ConvertFrom-Json $content -ErrorAction Stop
            
            # Handle old format (just aliases without favorites)
            if (-not ($config.PSObject.Properties.Name -contains 'favorites')) {
                return [PSCustomObject]@{
                    aliases = $config
                    favorites = @()
                }
            }
            
            # Ensure structure exists
            if (-not $config.aliases) {
                $config | Add-Member -NotePropertyName 'aliases' -NotePropertyValue ([PSCustomObject]@{}) -Force
            }
            
            # Normalize favorites to always be an array
            $normalizedFavorites = @()
            if ($config.favorites) {
                if ($config.favorites -is [string]) {
                    # Convert single string to array
                    $normalizedFavorites = @($config.favorites)
                }
                elseif ($config.favorites -is [array]) {
                    # Already an array, ensure all items are strings
                    $normalizedFavorites = @($config.favorites | Where-Object { $_ -is [string] })
                }
            }
            $config | Add-Member -NotePropertyName 'favorites' -NotePropertyValue $normalizedFavorites -Force
            
            return $config
        }
        catch {
            Write-Warning "Error loading configuration file: $_"
            return $this.CreateEmptyConfiguration()
        }
    }
    
    # Save configuration to file
    [bool] SaveConfiguration([PSCustomObject]$config) {
        try {
            $json = $config | ConvertTo-Json -Depth 10
            $json | Set-Content $this.ConfigFilePath -Encoding UTF8 -ErrorAction Stop
            return $true
        }
        catch {
            Write-Error "Error saving configuration file: $_"
            return $false
        }
    }
    
    # Create empty configuration structure
    [PSCustomObject] CreateEmptyConfiguration() {
        return [PSCustomObject]@{
            aliases = [PSCustomObject]@{}
            favorites = @()
        }
    }
    
    # Check if configuration file exists
    [bool] ConfigurationExists() {
        return Test-Path $this.ConfigFilePath
    }
    
    # Get configuration file info
    [hashtable] GetConfigurationInfo() {
        if (-not $this.ConfigurationExists()) {
            return @{
                Exists = $false
                Path = $this.ConfigFilePath
                Size = 0
                LastModified = $null
            }
        }
        
        $fileInfo = Get-Item $this.ConfigFilePath
        return @{
            Exists = $true
            Path = $this.ConfigFilePath
            Size = $fileInfo.Length
            LastModified = $fileInfo.LastWriteTime
        }
    }
}
