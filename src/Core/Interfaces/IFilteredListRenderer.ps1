<#
.SYNOPSIS
    IFilteredListRenderer - Interface for filtered list renderer
#>
class IFilteredListRenderer {
    [void] RenderFull([string]$title, [string]$searchText, [array]$items, [int]$selectedIndex, [int]$headerIndex, [string]$focusMode, [int]$viewportStart, [int]$pageSize, [int]$headerLines, [int]$totalCount, [string]$prompt, [string[]]$headerOptions, [bool]$clearScreen, [string]$currentItem, [string]$currentMarker, [string]$statusMessage, [ConsoleColor]$statusColor) {}
    [void] UpdateHeaderOptions([string[]]$headerOptions, [int]$headerIndex, [string]$focusMode, [int]$headerLines) {}
    [void] UpdateSearchInput([string]$searchText, [string]$focusMode, [int]$headerLines, [int]$headerOptionCount, [string]$prompt) {}
    [void] RenderList([array]$items, [int]$selectedIndex, [string]$focusMode, [int]$viewportStart, [int]$pageSize, [int]$headerOptionCount, [int]$headerLines, [int]$totalCount, [string]$currentItem, [string]$currentMarker, [string]$statusMessage, [ConsoleColor]$statusColor) {}
    [void] UpdateListSelection([array]$items, [int]$oldIndex, [int]$newIndex, [string]$focusMode, [int]$viewportStart, [int]$pageSize, [int]$headerOptionCount, [int]$headerLines, [int]$totalCount, [string]$currentItem, [string]$currentMarker) {}
    [void] RenderSingleItem([array]$items, [int]$index, [int]$viewportStart, [int]$startLine, [int]$selectedIndex, [string]$focusMode, [string]$currentItem, [string]$currentMarker) {}
}
