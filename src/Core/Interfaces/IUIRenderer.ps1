class IUIRenderer {
    # Header Rendering
    [void] RenderHeader([string]$title) {}
    [void] RenderHeader([string]$title, [string]$subtitle) {}
    [void] RenderHeader([string]$title, [string]$subtitle, [string]$highlight) {}
    [void] RenderHeader([string]$title, [string]$subtitle, [string]$highlight, [ConsoleColor]$highlightColor) {}
    [void] RenderHeader([string]$title, [string]$subtitle, [string]$highlight, [ConsoleColor]$highlightColor, [ConsoleColor]$borderColor) {}

    # Breadcrumb
    [void] RenderBreadcrumb([string]$path) {}

    # Workflow Headers
    [void] RenderWorkflowHeader([string]$title) {}
    [void] RenderWorkflowHeader([string]$title, [RepositoryModel]$repository) {}
    [void] RenderWorkflowHeaderWithInfo([string]$title, [RepositoryModel]$repository, [string]$infoLabel, [string]$infoValue, [ConsoleColor]$infoColor) {}

    # Menu
    [int] RenderMenu([string]$mode) { return 0 }

    # Repository List Rendering
    [void] RenderRepositoryItem([RepositoryModel]$repo, [bool]$isSelected) {}
    [void] RenderRepositoryList([NavigationState]$state, [int]$startLine) {}
    [void] UpdateRepositoryItemAt([int]$lineNumber, [RepositoryModel]$repo, [bool]$isSelected) {}

    # Color Picker Rendering
    [void] RenderColorItem([string]$color, [bool]$isSelected) {}
    [void] UpdateColorItemAt([int]$lineNumber, [string]$color, [bool]$isSelected) {}

    # Git Status Footer
    [void] ClearGitStatusFooter([int]$startLine) {}
    [void] RenderGitStatusFooter([RepositoryModel]$repo, [int]$totalItems, [int]$totalRepos, [int]$loadedRepos, [int]$currentIndex, [bool]$showHidden) {}

    # Messages
    [void] RenderError([string]$message) {}
    [void] RenderSuccess([string]$message) {}
    [void] RenderWarning([string]$message) {}
}
