<#
.SYNOPSIS
    PathManager - Single Source of Truth for repository paths.
    
.DESCRIPTION
    Centralizes all path operations following SOLID principles:
    - SRP: Only manages paths
    - DIP: Depends on UserPreferencesService abstraction
    
    Eliminates desync between memory (Context.BasePath) and file (preferences).
#>

class PathManager : IPathManager {
    [IUserPreferencesService] $PreferencesService
    [string] hidden $CachedCurrentPath = ""
    
    PathManager([IUserPreferencesService]$preferencesService) {
        $this.PreferencesService = $preferencesService
        $this.SyncFromPreferences()
    }
    
    # Syncs internal cache from preferences file
    [void] hidden SyncFromPreferences() {
        $prefs = $this.PreferencesService.LoadPreferences()
        $this.CachedCurrentPath = if ($prefs.Repository.DefaultPath) { 
            $prefs.Repository.DefaultPath 
        } else { 
            "" 
        }
    }
    
    # Gets the current active path (cached, always in sync)
    [string] GetCurrentPath() {
        return $this.CachedCurrentPath
    }
    
    # Sets the current path (updates both cache and file)
    [void] SetCurrentPath([string]$path) {
        if ([string]::IsNullOrWhiteSpace($path)) {
            $this.CachedCurrentPath = ""
            $this.PreferencesService.SetPreference("Repository", "DefaultPath", "")
        } else {
            $resolvedPath = $path
            if (Test-Path $path) {
                $resolvedPath = (Resolve-Path $path).Path
            }
            $this.CachedCurrentPath = $resolvedPath
            $this.PreferencesService.SetPreference("Repository", "DefaultPath", $resolvedPath)
        }
    }
    
    # Gets all configured paths (sanitized, never null)
    [string[]] GetAllPaths() {
        $prefs = $this.PreferencesService.LoadPreferences()
        return [ArrayHelper]::EnsureArray($prefs.Repository.Paths)
    }
    
    # Adds a path to the list (with validation)
    [bool] AddPath([string]$path) {
        if ([string]::IsNullOrWhiteSpace($path)) { return $false }
        if (-not (Test-Path $path)) { return $false }
        
        $resolvedPath = (Resolve-Path $path).Path
        $currentPaths = $this.GetAllPaths()
        
        if ([ArrayHelper]::Contains($currentPaths, $resolvedPath)) {
            return $true  # Already exists, not an error
        }
        
        $newPaths = [ArrayHelper]::AddToArray($currentPaths, $resolvedPath)
        $this.PreferencesService.SetPreference("Repository", "Paths", $newPaths)
        
        # If no current path set, set this as default
        if ([string]::IsNullOrWhiteSpace($this.CachedCurrentPath)) {
            $this.SetCurrentPath($resolvedPath)
        }
        
        return $true
    }
    
    # Removes a path from the list (handles defaultPath cleanup)
    [void] RemovePath([string]$path) {
        if ([string]::IsNullOrWhiteSpace($path)) { return }
        
        $currentPaths = $this.GetAllPaths()
        $newPaths = [ArrayHelper]::RemoveFromArray($currentPaths, $path)
        
        $this.PreferencesService.SetPreference("Repository", "Paths", $newPaths)
        
        # Update defaultPath if needed
        if ($this.CachedCurrentPath -eq $path -or $newPaths.Count -eq 0) {
            $newDefault = if ($newPaths.Count -gt 0) { $newPaths[0] } else { "" }
            $this.SetCurrentPath($newDefault)
        }
    }
    
    # Quick check if any paths are configured
    [bool] HasPaths() {
        return ($this.GetAllPaths().Count -gt 0)
    }
    
    # Forces a refresh from the preferences file
    [void] Refresh() {
        $this.SyncFromPreferences()
    }
}
