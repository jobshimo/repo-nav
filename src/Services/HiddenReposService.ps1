<#
.SYNOPSIS
    HiddenReposService - Manages hidden repositories list
    
.DESCRIPTION
    Following SOLID principles:
    - SRP: Only responsible for managing hidden repositories persistence
    - OCP: Open for extension, closed for modification
    - DIP: Depends on UserPreferencesService abstraction
    
    This service manages the list of repositories the user wants to hide
    from the main navigation view.
#>

class HiddenReposService {
    [UserPreferencesService] $PreferencesService
    
    # Runtime state for visibility toggle
    [bool] $ShowHiddenRepos
    
    # Constructor with dependency injection
    HiddenReposService([UserPreferencesService]$preferencesService) {
        $this.PreferencesService = $preferencesService
        # Initialize from preferences
        $this.ShowHiddenRepos = $this.GetDefaultVisibility()
    }
    
    # Check if a repository is hidden
    [bool] IsHidden([string]$repoName) {
        $hiddenList = $this.GetHiddenList()
        return $repoName -in $hiddenList
    }
    
    # Add a repository to the hidden list
    [bool] AddToHidden([string]$repoName) {
        if ([string]::IsNullOrWhiteSpace($repoName)) {
            return $false
        }
        
        $preferences = $this.PreferencesService.LoadPreferences()
        $this.EnsureHiddenSection($preferences)
        
        # Get current list
        $hiddenList = [System.Collections.ArrayList]@($preferences.hidden.hiddenRepos)
        
        # Check if already hidden
        if ($repoName -in $hiddenList) {
            return $true
        }
        
        # Add to list
        $hiddenList.Add($repoName) | Out-Null
        $preferences.hidden.hiddenRepos = $hiddenList.ToArray()
        
        return $this.PreferencesService.SavePreferences($preferences)
    }
    
    # Remove a repository from the hidden list
    [bool] RemoveFromHidden([string]$repoName) {
        if ([string]::IsNullOrWhiteSpace($repoName)) {
            return $false
        }
        
        $preferences = $this.PreferencesService.LoadPreferences()
        $this.EnsureHiddenSection($preferences)
        
        # Get current list
        $hiddenList = [System.Collections.ArrayList]@($preferences.hidden.hiddenRepos)
        
        # Remove from list
        if ($repoName -in $hiddenList) {
            $hiddenList.Remove($repoName)
            $preferences.hidden.hiddenRepos = $hiddenList.ToArray()
            return $this.PreferencesService.SavePreferences($preferences)
        }
        
        return $true
    }
    
    # Get the full list of hidden repositories
    [string[]] GetHiddenList() {
        $preferences = $this.PreferencesService.LoadPreferences()
        $this.EnsureHiddenSection($preferences)
        
        if ($preferences.hidden.hiddenRepos -is [array]) {
            return $preferences.hidden.hiddenRepos
        }
        return @()
    }
    
    # Get the count of hidden repositories
    [int] GetHiddenCount() {
        return $this.GetHiddenList().Count
    }
    
    # Clear all hidden repositories
    [bool] ClearAllHidden() {
        $preferences = $this.PreferencesService.LoadPreferences()
        $this.EnsureHiddenSection($preferences)
        
        $preferences.hidden.hiddenRepos = @()
        return $this.PreferencesService.SavePreferences($preferences)
    }
    
    # Get default visibility setting
    [bool] GetDefaultVisibility() {
        $preferences = $this.PreferencesService.LoadPreferences()
        $this.EnsureHiddenSection($preferences)
        
        return $preferences.hidden.defaultVisibility
    }
    
    # Set default visibility setting
    [bool] SetDefaultVisibility([bool]$visible) {
        $preferences = $this.PreferencesService.LoadPreferences()
        $this.EnsureHiddenSection($preferences)
        
        $preferences.hidden.defaultVisibility = $visible
        return $this.PreferencesService.SavePreferences($preferences)
    }
    
    # Toggle runtime visibility state
    [bool] ToggleShowHidden() {
        $this.ShowHiddenRepos = -not $this.ShowHiddenRepos
        return $this.ShowHiddenRepos
    }
    
    # Get current runtime visibility state
    [bool] GetShowHiddenState() {
        return $this.ShowHiddenRepos
    }
    
    # Set runtime visibility state
    [void] SetShowHiddenState([bool]$show) {
        $this.ShowHiddenRepos = $show
    }
    
    # Helper: Ensure hidden section exists in preferences
    hidden [void] EnsureHiddenSection([PSCustomObject]$preferences) {
        if (-not ($preferences.PSObject.Properties.Name -contains 'hidden')) {
            $preferences | Add-Member -NotePropertyName 'hidden' -NotePropertyValue ([PSCustomObject]@{
                defaultVisibility = $false
                hiddenRepos = @()
            }) -Force
        }
        
        if (-not ($preferences.hidden.PSObject.Properties.Name -contains 'defaultVisibility')) {
            $preferences.hidden | Add-Member -NotePropertyName 'defaultVisibility' -NotePropertyValue $false -Force
        }
        
        if (-not ($preferences.hidden.PSObject.Properties.Name -contains 'hiddenRepos')) {
            $preferences.hidden | Add-Member -NotePropertyName 'hiddenRepos' -NotePropertyValue @() -Force
        }
    }
}
