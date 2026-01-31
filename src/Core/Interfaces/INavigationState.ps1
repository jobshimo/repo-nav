class INavigationState {
    # Navigation
    [void] SelectNext() {}
    [void] SelectPrevious() {}
    [void] SelectIndex([int]$index) {}
    
    # State Management
    [void] Stop() {}
    [object] GetSelectedRepository() { return $null }
    [object] GetPreviousRepository() { return $null }
    [void] UpdateRepositories([array]$repositories) {}
    [int] FindRepositoryIndex([string]$repoName) { return 0 }
    
    # Rendering Flags
    [void] MarkForFullRedraw() {}
    [void] MarkForPartialRedraw() {}
    [void] MarkForListRedraw() {}
    [void] ClearRedrawFlags() {}
    [void] ClearFullRedrawFlag() {}
    [void] ClearSelectionChangedFlag() {}
    [bool] NeedsFullRedraw() { return $false }
    [bool] HasSelectionChanged() { return $false }
    [bool] NeedsRedraw() { return $false }
    
    # Exit State
    [void] SetExitState([string]$exitState) {}
    [string] GetExitState() { return "" }
    [bool] ShouldExit() { return $false }
    [void] Resume() {}
    
    # Getters/Setters
    [array] GetRepositories() { return $null }
    [void] SetRepositories([array]$repositories) {}
    [int] GetCurrentIndex() { return 0 }
    [void] SetCurrentIndex([int]$index) {}
    [int] GetPreviousIndex() { return 0 }
    [void] UpdateWindowSize([int]$headerHeight) {}
    
    # Statistics
    [int] GetTotalCount() { return 0 }
    [int] GetLoadedCount() { return 0 }
    [int] GetRepoCount() { return 0 }
    
    # Hierarchical Navigation
    [void] EnterContainer([string]$containerPath, [array]$newRepositories) {}
    [bool] GoBack() { return $false }
    [bool] CanGoBack() { return $false }
    [int] GetNavigationDepth() { return 0 }
    [string] GetBreadcrumb() { return "" }
    [string] GetParentPath() { return "" }
    [bool] IsInsideContainer() { return $false }
    [string] GetCurrentPath() { return "" }
    [void] SetCurrentPath([string]$path) {}
    [void] SetBasePath([string]$path) {}
    
    # Focus Management
    [void] ToggleFocus() {}
    [void] SetFocus([string]$focus) {}
    [string] GetFocus() { return "" }
    [bool] IsListFocused() { return $false }
    [bool] IsHeaderFocused() { return $false }
}
