<#
.SYNOPSIS
    PreferenceUpdateResult - Return type for preference modification actions
#>
class PreferenceUpdateResult {
    [bool] $Updated
    [string] $Message
    [int] $Timeout

    PreferenceUpdateResult([bool]$updated, [string]$message, [int]$timeout) {
        $this.Updated = $updated
        $this.Message = $message
        $this.Timeout = $timeout
    }

    static [PreferenceUpdateResult] NoChange() {
        return [PreferenceUpdateResult]::new($false, "", 0)
    }

    static [PreferenceUpdateResult] Changed([string]$message, [int]$timeout) {
        return [PreferenceUpdateResult]::new($true, $message, $timeout)
    }
}
