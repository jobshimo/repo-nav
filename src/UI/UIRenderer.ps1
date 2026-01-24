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
    
    # Constructor with dependency injection
    UIRenderer([ConsoleHelper]$console, [UserPreferencesService]$preferencesService) {
        $this.Console = $console
        $this.PreferencesService = $preferencesService
    }
    
    # Render header
    [void] RenderHeader([string]$title) {
        $separator = "=" * 55
        Write-Host $separator -ForegroundColor ([Constants]::ColorSeparator)
        Write-Host "    $title" -ForegroundColor ([Constants]::ColorHeader)
        Write-Host $separator -ForegroundColor ([Constants]::ColorSeparator)
    }
    
    # Render interactive workflow header with repository info
    [void] RenderWorkflowHeader([string]$title, [RepositoryModel]$repository) {
        $separator = "=" * 55
        Write-Host $separator -ForegroundColor ([Constants]::ColorSeparator)
        Write-Host "    $title" -ForegroundColor ([Constants]::ColorHeader)
        Write-Host $separator -ForegroundColor ([Constants]::ColorSeparator)
        Write-Host "Repository: " -NoNewline -ForegroundColor ([Constants]::ColorPrompt)
        Write-Host $repository.Name -ForegroundColor ([Constants]::ColorValue)
        Write-Host $separator -ForegroundColor ([Constants]::ColorSeparator)
        Write-Host ""
    }
    
    # Render interactive workflow header with additional info line
    [void] RenderWorkflowHeaderWithInfo([string]$title, [RepositoryModel]$repository, [string]$infoLabel, [string]$infoValue, [ConsoleColor]$infoColor) {
        $separator = "=" * 55
        Write-Host $separator -ForegroundColor ([Constants]::ColorSeparator)
        Write-Host "    $title" -ForegroundColor ([Constants]::ColorHeader)
        Write-Host $separator -ForegroundColor ([Constants]::ColorSeparator)
        Write-Host "Repository: " -NoNewline -ForegroundColor ([Constants]::ColorPrompt)
        Write-Host $repository.Name -ForegroundColor ([Constants]::ColorValue)
        Write-Host "$infoLabel : " -NoNewline -ForegroundColor ([Constants]::ColorPrompt)
        Write-Host $infoValue -ForegroundColor $infoColor
        Write-Host $separator -ForegroundColor ([Constants]::ColorSeparator)
        Write-Host ""
    }
    
    # Render menu/instructions
    [void] RenderMenu() {
        Write-Host ""
        Write-Host "  Navigation: Arrows | Enter=open | Q=quit | U=preferences" -ForegroundColor ([Constants]::ColorMenuText)
        Write-Host "  Aliases:    E=set | R=remove" -ForegroundColor ([Constants]::ColorMenuText)
        Write-Host "  Modules:    I=install | X=remove" -ForegroundColor ([Constants]::ColorMenuText)
        Write-Host "  Repository: C=clone | Del=delete | F=favorite" -ForegroundColor ([Constants]::ColorMenuText)
        Write-Host "  Git Status: L=load current | G=load all missing" -ForegroundColor ([Constants]::ColorMenuText)
        Write-Host ""
    }
    
    # Get git status display info
    [hashtable] GetGitStatusDisplay([GitStatusModel]$gitStatus) {
        if (-not $gitStatus -or -not $gitStatus.IsGitRepo) {
            return @{
                Symbol = "?"
                Color = ([Constants]::ColorGitUnknown)
                Description = "Not a git repository"
            }
        }
        
        # Priority: Uncommitted > Unpushed > Clean
        if ($gitStatus.HasUncommittedChanges) {
            return @{
                Symbol = [Constants]::GitSymbolUncommitted
                Color = ([Constants]::ColorGitUncommitted)
                Description = "Uncommitted changes"
            }
        }
        
        if ($gitStatus.HasUnpushedCommits) {
            return @{
                Symbol = [Constants]::GitSymbolUnpushed
                Color = ([Constants]::ColorGitUnpushed)
                Description = "Unpushed commits"
            }
        }
        
        return @{
            Symbol = [Constants]::GitSymbolClean
            Color = ([Constants]::ColorGitClean)
            Description = "Clean repository"
        }
    }
    
    # Render a single repository list item
    [void] RenderRepositoryItem([RepositoryModel]$repo, [bool]$isSelected) {
        # Get user-configured background color and delimiter
        $backgroundColor = $null
        $selectedTextColor = [Constants]::ColorSelected
        $leftDelimiter = ''
        $rightDelimiter = ''
        
        if ($isSelected) {
            $preferences = $this.PreferencesService.LoadPreferences()
            $bgColor = $preferences.display.selectedBackground
            
            if ($bgColor -ne 'None') {
                $backgroundColor = $bgColor
            }
            
            # Get optimal text color based on background for better contrast
            $selectedTextColor = [Constants]::GetTextColorForBackground($bgColor)
            
            # Get delimiter
            $delimiterName = $preferences.display.selectedDelimiter
            $delimiter = [Constants]::AvailableDelimiters | Where-Object { $_.Name -eq $delimiterName } | Select-Object -First 1
            if ($delimiter) {
                $leftDelimiter = $delimiter.Left
                $rightDelimiter = $delimiter.Right
            }
        }
        
        # Determine name color
        $nameColor = if (-not $repo.HasNodeModules) { 
            [Constants]::ColorRepoWithoutModules  # Red si no tiene node_modules
        } elseif ($isSelected) { 
            $selectedTextColor  # Color optimizado según fondo
        } else { 
            [Constants]::ColorUnselected  # Blanco cuando no está seleccionado
        }
        
        $prefix = if ($isSelected) { "  > " } else { "    " }
        
        # Get git status display
        $gitDisplay = $this.GetGitStatusDisplay($repo.GitStatus)
        
        # Render prefix - usar color optimizado
        Write-Host $prefix -NoNewline -ForegroundColor $(if ($isSelected) { $selectedTextColor } else { [Constants]::ColorUnselected })
        
        # Render favorite indicator
        if ($repo.IsFavorite) {
            Write-Host "$([Constants]::FavoriteSymbol) " -NoNewline -ForegroundColor ([Constants]::ColorFavorite)
        } else {
            Write-Host "  " -NoNewline
        }
        
        # Render git indicator
        Write-Host "$($gitDisplay.Symbol) " -NoNewline -ForegroundColor $gitDisplay.Color
        
        # Render left delimiter
        if ($leftDelimiter -ne '') {
            if ($backgroundColor) {
                Write-Host $leftDelimiter -NoNewline -ForegroundColor $selectedTextColor -BackgroundColor $backgroundColor
            } else {
                Write-Host $leftDelimiter -NoNewline -ForegroundColor $selectedTextColor
            }
        }
        
        # Render repo name
        if ($backgroundColor) {
            Write-Host $repo.Name -NoNewline -ForegroundColor $nameColor -BackgroundColor $backgroundColor
        } else {
            Write-Host $repo.Name -NoNewline -ForegroundColor $nameColor
        }
        
        # Render right delimiter
        if ($rightDelimiter -ne '') {
            if ($backgroundColor) {
                Write-Host $rightDelimiter -NoNewline -ForegroundColor $selectedTextColor -BackgroundColor $backgroundColor
            } else {
                Write-Host $rightDelimiter -NoNewline -ForegroundColor $selectedTextColor
            }
        }
        
        # Render alias if exists (always without background)
        if ($repo.HasAlias -and $repo.AliasInfo) {
            $aliasText = " - $($repo.AliasInfo.Alias)"
            Write-Host $aliasText -ForegroundColor $repo.AliasInfo.Color
        } else {
            Write-Host ""
        }
    }
    
    # Render repository item at specific line (optimized update)
    [void] UpdateRepositoryItemAt([int]$lineNumber, [RepositoryModel]$repo, [bool]$isSelected) {
        $this.Console.SetCursorPosition(0, $lineNumber)
        $this.Console.ClearCurrentLine()
        $this.RenderRepositoryItem($repo, $isSelected)
    }
    
    # Render color selection item
    [void] RenderColorItem([string]$color, [bool]$isSelected) {
        $backgroundColor = $null
        if ($isSelected) {
            $preferences = $this.PreferencesService.LoadPreferences()
            $bgColor = $preferences.display.selectedBackground
            if ($bgColor -ne 'None') {
                $backgroundColor = $bgColor
            }
        }
        
        if ($isSelected) {
            Write-Host "  > " -NoNewline -ForegroundColor ([Constants]::ColorSelected)
            if ($backgroundColor) {
                Write-Host $color -ForegroundColor $color -BackgroundColor $backgroundColor
            } else {
                Write-Host $color -ForegroundColor $color
            }
        } else {
            Write-Host "    " -NoNewline
            Write-Host $color -ForegroundColor $color
        }
    }
    
    # Update color item at specific line
    [void] UpdateColorItemAt([int]$lineNumber, [string]$color, [bool]$isSelected) {
        $this.Console.SetCursorPosition(0, $lineNumber)
        $this.Console.ClearCurrentLine()
        $this.RenderColorItem($color, $isSelected)
    }
    
    # Clear the git status footer area (4 lines)
    [void] ClearGitStatusFooter([int]$startLine) {
        for ($i = 0; $i -lt 4; $i++) {
            $this.Console.SetCursorPosition(0, $startLine + $i)
            $this.Console.ClearCurrentLine()
        }
        $this.Console.SetCursorPosition(0, $startLine)
    }
    
    # Render git status footer
    [void] RenderGitStatusFooter([RepositoryModel]$repo, [int]$totalRepos, [int]$loadedRepos) {
        # Line 1: Separator
        Write-Host ("=" * 55) -ForegroundColor ([Constants]::ColorSeparator)
        
        # Line 2: Counters (single line, pad to clear residuals)
        Write-Host "Repos: " -NoNewline -ForegroundColor ([Constants]::ColorLabel)
        Write-Host "$totalRepos" -NoNewline -ForegroundColor ([Constants]::ColorValue)
        Write-Host " | Git Info: " -NoNewline -ForegroundColor ([Constants]::ColorLabel)
        
        $counterColor = if ($loadedRepos -eq $totalRepos) { [Constants]::ColorCounterComplete } 
                       elseif ($loadedRepos -eq 0) { [Constants]::ColorCounterEmpty } 
                       else { [Constants]::ColorCounterPartial }
        Write-Host "$loadedRepos" -ForegroundColor $counterColor  # This adds newline
        
        # Line 3: Git status details (single line, pad to clear residuals)
        if (-not $repo.HasGitStatusLoaded()) {
            Write-Host "Git Status: " -NoNewline -ForegroundColor ([Constants]::ColorLabel)
            Write-Host "Not loaded " -NoNewline -ForegroundColor ([Constants]::ColorHint)
            Write-Host "(press L to load current or G for all)" -ForegroundColor ([Constants]::ColorWarning)  # Adds newline
        } else {
            $gitStatus = $repo.GitStatus
            
            if (-not $gitStatus.IsGitRepo) {
                Write-Host "Git Status: " -NoNewline -ForegroundColor ([Constants]::ColorLabel)
                Write-Host "Not a git repository" -ForegroundColor ([Constants]::ColorHint)  # Adds newline
            } else {
                Write-Host "Git Status: " -NoNewline -ForegroundColor ([Constants]::ColorLabel)
                Write-Host "Branch: " -NoNewline -ForegroundColor ([Constants]::ColorHighlight)
                Write-Host $gitStatus.CurrentBranch -NoNewline -ForegroundColor ([Constants]::ColorValue)
                Write-Host " | " -NoNewline -ForegroundColor ([Constants]::ColorLabel)
                
                $gitDisplay = $this.GetGitStatusDisplay($gitStatus)
                Write-Host "$($gitDisplay.Symbol) $($gitDisplay.Description)" -ForegroundColor $gitDisplay.Color  # Adds newline
            }
        }
        
        # Line 4: Separator
        Write-Host ("=" * 55) -ForegroundColor ([Constants]::ColorSeparator)
    }
    
    # Render error message
    [void] RenderError([string]$message) {
        Write-Host "Error: $message" -ForegroundColor ([Constants]::ColorError)
    }
    
    # Render success message
    [void] RenderSuccess([string]$message) {
        Write-Host $message -ForegroundColor ([Constants]::ColorSuccess)
    }
    
    # Render warning message
    [void] RenderWarning([string]$message) {
        Write-Host $message -ForegroundColor ([Constants]::ColorWarning)
    }
}
