<#
.SYNOPSIS
    Collection of mock service implementations for testing
    
.DESCRIPTION
    Provides lightweight mocks for common services used in tests.
#>

class MockUserPreferencesService {
    [hashtable] $Preferences = @{}
    
    [PSCustomObject] LoadPreferences() {
        return [PSCustomObject]@{
            display = [PSCustomObject]@{
                showHeaders = $true
                favoritesPosition = "top"
                selectedBackground = "None"
                selectedDelimiter = "None"
            }
            git = [PSCustomObject]@{
                autoLoadStatus = "none"
            }
            general = [PSCustomObject]@{
                language = "en"
            }
        }
    }
    
    [object] GetPreference([string]$category, [string]$key) {
        $key = "$category.$key"
        if ($this.Preferences.ContainsKey($key)) {
            return $this.Preferences[$key]
        }
        return $null
    }
    
    [void] SetPreference([string]$category, [string]$key, [object]$value) {
        $fullKey = "$category.$key"
        $this.Preferences[$fullKey] = $value
    }
}

class MockLocalizationService {
    [hashtable] $Translations = @{}
    
    MockLocalizationService() {
        # Default English translations
        $this.Translations["App.Title"] = "Repository Navigator"
        $this.Translations["Nav.BackHint"] = "< back"
        $this.Translations["Error.Generic"] = "An error occurred: {0}"
    }
    
    [string] Get([string]$key) {
        if ($this.Translations.ContainsKey($key)) {
            return $this.Translations[$key]
        }
        return $key
    }
    
    [void] SetLanguage([string]$lang) {
        # Mock implementation - do nothing
    }
}

class MockConfigurationService {
    [PSCustomObject] $Config
    
    MockConfigurationService() {
        $this.Config = [PSCustomObject]@{
            aliases = [PSCustomObject]@{}
            favorites = @()
        }
    }
    
    [PSCustomObject] LoadConfiguration() {
        return $this.Config
    }
    
    [bool] SaveConfiguration([PSCustomObject]$config) {
        $this.Config = $config
        return $true
    }
    
    [PSCustomObject] CreateEmptyConfiguration() {
        return [PSCustomObject]@{
            aliases = [PSCustomObject]@{}
            favorites = @()
        }
    }
}

class MockGitService {
    [hashtable] $GitStatuses = @{}
    
    [object] GetGitStatus([string]$path) {
        if ($this.GitStatuses.ContainsKey($path)) {
            return $this.GitStatuses[$path]
        }
        return @{
            IsGitRepository = $true
            CurrentBranch = "main"
            HasUncommittedChanges = $false
            HasUnpushedCommits = $false
        }
    }
    
    [bool] IsGitRepository([string]$path) {
        return $true
    }
    
    # Test helper: Set fake status
    [void] SetFakeStatus([string]$path, [hashtable]$status) {
        $this.GitStatuses[$path] = $status
    }
}
