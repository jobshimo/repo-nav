class IHiddenReposService {
    [bool] IsHidden([string]$repoPath) { return $false }
    [bool] AddToHidden([string]$repoPath) { return $false }
    [bool] RemoveFromHidden([string]$repoPath) { return $false }
    [string[]] GetHiddenList() { return @() }
    [int] GetHiddenCount() { return 0 }
    [bool] ClearAllHidden() { return $false }
    [bool] ToggleShowHidden() { return $false }
    [bool] GetShowHiddenState() { return $false }
    [void] SetShowHiddenState([bool]$show) {}
}
