<#
.SYNOPSIS
    IPreferencesMenuRenderer - Interface for preferences menu renderer
#>
class IPreferencesMenuRenderer {
    [void] RenderMenu([array]$items, [int]$selectedIndex, [int]$startTop, [int]$viewportStart, [int]$pageSize, [scriptblock]$GetLoc) {}
    [void] RenderFooter([string]$message, [int]$timeout, [int]$footerStart, [scriptblock]$GetLoc) {}
    [int] RenderHeader([string]$title) { return 0 }
}
