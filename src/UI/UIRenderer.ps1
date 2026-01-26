<#
.SYNOPSIS
    UIRenderer - Handles rendering of UI elements
    
.DESCRIPTION
    Following SOLID principles:
    - SRP: Only responsible for rendering UI elements
    - ISP: Focused interface for different UI components
    - DIP: Depends on ConsoleHelper abstraction
    
    This class renders:
    - Headers and footers
    - Repository list items
    - Git status indicators
    - Color previews
#>

class UIRenderer {
    [ConsoleHelper] $Console
    [UserPreferencesService] $PreferencesService
    [LocalizationService] $LocalizationService
    [MenuRenderer] $MenuRenderer
    [RepositoryListRenderer] $RepoListRenderer
    [StatusRenderer] $StatusRenderer
    [HeaderRenderer] $HeaderRenderer
    [FeedbackRenderer] $FeedbackRenderer
    [ColorRenderer] $ColorRenderer
    
    # Constructor with dependency injection
    UIRenderer([ConsoleHelper]$console, [UserPreferencesService]$preferencesService, [LocalizationService]$localizationService, [MenuRenderer]$menuRenderer, [RepositoryListRenderer]$repoListRenderer, [StatusRenderer]$statusRenderer, [HeaderRenderer]$headerRenderer, [FeedbackRenderer]$feedbackRenderer, [ColorRenderer]$colorRenderer) {
        $this.Console = $console
        $this.PreferencesService = $preferencesService
        $this.LocalizationService = $localizationService
        $this.MenuRenderer = $menuRenderer
        $this.RepoListRenderer = $repoListRenderer
        $this.StatusRenderer = $statusRenderer
        $this.HeaderRenderer = $headerRenderer
        $this.FeedbackRenderer = $feedbackRenderer
        $this.ColorRenderer = $colorRenderer
    }

    # Helper for localization
    [string] GetLoc([string]$key, [string]$default) {
        if ($null -ne $this.LocalizationService) {
            return $this.LocalizationService.Get($key)
        }
        return $default
    }
    
    # Render header
    [void] RenderHeader([string]$title) {
        if ($null -ne $this.HeaderRenderer) {
            $this.HeaderRenderer.RenderHeader($title)
        }
    }
    
    # Render breadcrumb for hierarchical navigation
    [void] RenderBreadcrumb([string]$path) {
        if ($null -ne $this.HeaderRenderer) {
            $this.HeaderRenderer.RenderBreadcrumb($path)
        }
    }
    
    # Render simple workflow header (title only)
    [void] RenderWorkflowHeader([string]$title) {
        if ($null -ne $this.HeaderRenderer) {
            $this.HeaderRenderer.RenderWorkflowHeader($title)
        }
    }
    
    # Render interactive workflow header with repository info
    [void] RenderWorkflowHeader([string]$title, [RepositoryModel]$repository) {
        if ($null -ne $this.HeaderRenderer) {
            $this.HeaderRenderer.RenderWorkflowHeader($title, $repository)
        }
    }
    
    # Render interactive workflow header with additional info line
    [void] RenderWorkflowHeaderWithInfo([string]$title, [RepositoryModel]$repository, [string]$infoLabel, [string]$infoValue, [ConsoleColor]$infoColor) {
        if ($null -ne $this.HeaderRenderer) {
            $this.HeaderRenderer.RenderWorkflowHeaderWithInfo($title, $repository, $infoLabel, $infoValue, $infoColor)
        }
    }
    
    # Render menu/instructions
    [int] RenderMenu([string]$mode) {
        if ($null -ne $this.MenuRenderer) {
            return $this.MenuRenderer.RenderMenu($mode)
        }
        return 0
    }
    
    # Render visible repository list based on Viewport
    [void] RenderRepositoryList([NavigationState]$state, [int]$startLine) {
        if ($null -ne $this.RepoListRenderer) {
            $this.RepoListRenderer.RenderRepositoryList($state, $startLine)
        }
    }
    
    # Render repository item at specific line (optimized update)
    [void] UpdateRepositoryItemAt([int]$lineNumber, [RepositoryModel]$repo, [bool]$isSelected) {
        if ($null -ne $this.RepoListRenderer) {
            $this.RepoListRenderer.UpdateRepositoryItemAt($lineNumber, $repo, $isSelected)
        }
    }
    
    # Render color selection item
    [void] RenderColorItem([string]$color, [bool]$isSelected) {
        if ($null -ne $this.ColorRenderer) {
            $this.ColorRenderer.RenderColorItem($color, $isSelected)
        }
    }
    
    # Update color item at specific line
    [void] UpdateColorItemAt([int]$lineNumber, [string]$color, [bool]$isSelected) {
         if ($null -ne $this.ColorRenderer) {
            $this.ColorRenderer.UpdateColorItemAt($lineNumber, $color, $isSelected)
        }
    }
    
    # Clear the git status footer area (4 lines)
    [void] ClearGitStatusFooter([int]$startLine) {
        if ($null -ne $this.StatusRenderer) {
            $this.StatusRenderer.ClearGitStatusFooter($startLine)
        }
    }
    
    # Render git status footer
    # Now receives additional counts: totalItems (all), totalRepos (only non-containers), loadedRepos (git status loaded)
    [void] RenderGitStatusFooter([RepositoryModel]$repo, [int]$totalItems, [int]$totalRepos, [int]$loadedRepos, [int]$currentIndex) {
        if ($null -ne $this.StatusRenderer) {
            $this.StatusRenderer.RenderGitStatusFooter($repo, $totalItems, $totalRepos, $loadedRepos, $currentIndex)
        }
    }
    
    # Render error message
    [void] RenderError([string]$message) {
        if ($null -ne $this.FeedbackRenderer) {
            $this.FeedbackRenderer.RenderError($message)
        }
    }
    
    # Render success message
    [void] RenderSuccess([string]$message) {
         if ($null -ne $this.FeedbackRenderer) {
            $this.FeedbackRenderer.RenderSuccess($message)
        }
    }
    
    # Render warning message
    [void] RenderWarning([string]$message) {
         if ($null -ne $this.FeedbackRenderer) {
            $this.FeedbackRenderer.RenderWarning($message)
        }
    }
}
