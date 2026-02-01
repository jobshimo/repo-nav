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

class ConfigurationService : IConfigurationService {
    [string] $ConfigFilePath      # Aliases
    
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
            if ([string]::IsNullOrWhiteSpace($content)) {
                return $this.CreateEmptyConfiguration()
            }
            # -AsHashtable is safer for manipulation in PS 5+ but let's stick to object and rebuild
            $jsonObj = ConvertFrom-Json $content -ErrorAction Stop
            
            # Normalize Aliases
            $aliases = if ($jsonObj.PSObject.Properties.Match('aliases').Count) { $jsonObj.aliases } else { $jsonObj }
            # If root aliases property exists, use it. If not (legacy), assume root IS aliases (unless favorites exists)
            
            # Handle legacy root-level aliases
            if (-not ($jsonObj.PSObject.Properties.Match('aliases').Count) -and 
                -not ($jsonObj.PSObject.Properties.Match('favorites').Count)) {
                $aliases = $jsonObj
            } elseif ($null -eq $aliases) {
                # Aliases property exists but is null?
                $aliases = [PSCustomObject]@{}
            }

            # Normalize Favorites
            $favorites = @()
            if ($jsonObj.PSObject.Properties.Match('favorites').Count -and $null -ne $jsonObj.favorites) {
                if ($jsonObj.favorites -is [string]) {
                     $favorites = @($jsonObj.favorites)
                } elseif ($jsonObj.favorites -is [array]) {
                     $favorites = @($jsonObj.favorites | Where-Object { $_ -is [string] })
                }
            }

            # Reconstruct clean object
            return [PSCustomObject]@{
                aliases = $aliases
                favorites = $favorites
            }
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
