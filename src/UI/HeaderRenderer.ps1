<#
.SYNOPSIS
    HeaderRenderer - Handles rendering of headers and breadcrumbs
    
.DESCRIPTION
    Extracted from UIRenderer to follow SRP.
    Responsible for rendering headers, breadcrumbs and workflow titles.
#>

class HeaderRenderer {
    [ConsoleHelper] $Console
    [LocalizationService] $LocalizationService

    # Constructor
    HeaderRenderer([ConsoleHelper]$console, [LocalizationService]$localizationService) {
        $this.Console = $console
        $this.LocalizationService = $localizationService
    }

    # Helper for localization
    hidden [string] GetLoc([string]$key, [string]$default) {
        if ($null -ne $this.LocalizationService) {
            return $this.LocalizationService.Get($key)
        }
        return $default
    }
    
    # Render header
    [void] RenderHeader([string]$title) {
        $this.Console.WriteSeparator("=", [Constants]::UIWidth, [Constants]::ColorSeparator)
        $this.Console.WriteLineColored("    $title", [Constants]::ColorHeader)
        $this.Console.WriteSeparator("=", [Constants]::UIWidth, [Constants]::ColorSeparator)
    }
    
    # Render breadcrumb for hierarchical navigation
    [void] RenderBreadcrumb([string]$path) {
        $backHint = $this.GetLoc("Nav.BackHint", "< back")
        $this.Console.WriteColored("  $backHint | ", [Constants]::ColorHint)
        $this.Console.WriteColored("Path: ", [Constants]::ColorLabel)
        $this.Console.WriteLineColored($path, [Constants]::ColorHighlight)
    }
    
    # Render simple workflow header (title only)
    [void] RenderWorkflowHeader([string]$title) {
        $this.Console.WriteSeparator("=", [Constants]::UIWidth, [Constants]::ColorSeparator)
        $this.Console.WriteLineColored("    $title", [Constants]::ColorHeader)
        $this.Console.WriteSeparator("=", [Constants]::UIWidth, [Constants]::ColorSeparator)
        $this.Console.NewLine()
    }
    
    # Render interactive workflow header with repository info
    [void] RenderWorkflowHeader([string]$title, [RepositoryModel]$repository) {
        $this.Console.WriteSeparator("=", [Constants]::UIWidth, [Constants]::ColorSeparator)
        $this.Console.WriteLineColored("    $title", [Constants]::ColorHeader)
        $this.Console.WriteSeparator("=", [Constants]::UIWidth, [Constants]::ColorSeparator)
        $this.Console.WriteColored(("{0}: " -f $this.GetLoc("UI.Group.Repo", "Repository")), [Constants]::ColorPrompt)
        $this.Console.WriteLineColored($repository.Name, [Constants]::ColorValue)
        $this.Console.WriteSeparator("=", [Constants]::UIWidth, [Constants]::ColorSeparator)
        $this.Console.NewLine()
    }
    
    # Render interactive workflow header with additional info line
    [void] RenderWorkflowHeaderWithInfo([string]$title, [RepositoryModel]$repository, [string]$infoLabel, [string]$infoValue, [ConsoleColor]$infoColor) {
        $this.Console.WriteSeparator("=", [Constants]::UIWidth, [Constants]::ColorSeparator)
        $this.Console.WriteLineColored("    $title", [Constants]::ColorHeader)
        $this.Console.WriteSeparator("=", [Constants]::UIWidth, [Constants]::ColorSeparator)
        $this.Console.WriteColored("Repository: ", [Constants]::ColorPrompt)
        $this.Console.WriteLineColored($repository.Name, [Constants]::ColorValue)
        $this.Console.WriteColored("$infoLabel : ", [Constants]::ColorPrompt)
        $this.Console.WriteLineColored($infoValue, $infoColor)
        $this.Console.WriteSeparator("=", [Constants]::UIWidth, [Constants]::ColorSeparator)
        $this.Console.NewLine()
    }
}
