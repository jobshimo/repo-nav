class IPathManager {
    [string] GetCurrentPath() { return "" }
    [void] SetCurrentPath([string]$path) {}
    [string[]] GetAllPaths() { return @() }
    [bool] AddPath([string]$path) { return $false }
    [void] RemovePath([string]$path) {}
    [bool] HasPaths() { return $false }
    [void] Refresh() {}
}
