<#
.SYNOPSIS
    IPreferencesActionDispatcher - Interface for preferences action dispatcher
#>
class IPreferencesActionDispatcher {
    [PreferenceUpdateResult] Dispatch([hashtable]$item, [UserPreferences]$preferences, [scriptblock]$GetLoc) { return [PreferenceUpdateResult]::NoChange() }
}
