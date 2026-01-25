<#
.SYNOPSIS
    SearchView - Interactive search interface for repositories
    
.DESCRIPTION
    Following SOLID principles:
    - SRP: Only responsible for search UI rendering and interaction
    - DIP: Depends on ConsoleHelper, UIRenderer, SearchService abstractions
    
    This view provides:
    - Real-time filtering as user types
    - Seamless navigation between search input and results list
    - Keyboard-driven interface (Tab, Arrows, Enter, Esc)
    - Dynamic viewport that adapts to window size (like main view)
#>

class SearchView {
    [ConsoleHelper] $Console
    [UIRenderer] $Renderer
    [SearchService] $SearchService
    [LocalizationService] $LocalizationService
    [WindowSizeCalculator] $WindowCalculator
    
    # Layout constants
    [int] $HeaderLines = 3          # Title separator lines
    [int] $SearchInputLines = 3     # Search label + input + blank
    [int] $CounterLines = 2         # Result count + blank
    [int] $SeparatorLines = 1       # Separator before list
    [int] $FooterLines = 4          # Separator + hints + blank + separator
    
    # Constructor with dependency injection
    SearchView([ConsoleHelper]$console, [UIRenderer]$renderer, [LocalizationService]$localizationService) {
        $this.Console = $console
        $this.Renderer = $renderer
        $this.SearchService = [SearchService]::new()
        $this.LocalizationService = $localizationService
        $this.WindowCalculator = [WindowSizeCalculator]::new()
    }
    
    # Helper for localization
    hidden [string] GetLoc([string]$key, [string]$default) {
        if ($null -ne $this.LocalizationService) {
            return $this.LocalizationService.Get($key)
        }
        return $default
    }
    
    <#
    .SYNOPSIS
        Calculates the available page size for the results list
    #>
    hidden [int] CalculatePageSize() {
        $reservedLines = $this.HeaderLines + $this.SearchInputLines + $this.CounterLines + $this.SeparatorLines + $this.FooterLines + 2
        $windowHeight = $this.WindowCalculator.GetWindowHeight()
        $available = $windowHeight - $reservedLines
        
        # Bounds
        if ($available -lt 3) { return 3 }
        if ($available -gt 20) { return 20 }
        return $available
    }
    
    <#
    .SYNOPSIS
        Shows the search interface and returns the selected repository
        
    .PARAMETER allRepos
        Complete list of repositories to search
        
    .PARAMETER currentRepo
        Currently selected repository (to preserve selection if in results)
        
    .RETURNS
        Hashtable with: { SelectedRepo, SelectedIndex, Cancelled }
    #>
    [hashtable] Show([array]$allRepos, [object]$currentRepo) {
        if ($null -eq $allRepos -or $allRepos.Count -eq 0) {
            return @{
                SelectedRepo  = $null
                SelectedIndex = -1
                Cancelled     = $true
            }
        }
        
        # State variables
        $searchText = ""
        $filteredRepos = $allRepos
        $selectedIndex = 0
        $focusMode = "input"  # "input" or "list"
        $running = $true
        $cancelled = $false
        
        # Viewport state
        $viewportStart = 0
        $pageSize = $this.CalculatePageSize()
        
        # If we have a current repo, try to find it in the list
        if ($null -ne $currentRepo) {
            $selectedIndex = $this.SearchService.FindRepositoryIndex($filteredRepos, $currentRepo)
        }
        
        # Calculate line positions
        $listStartLine = $this.HeaderLines + $this.SearchInputLines + $this.CounterLines + $this.SeparatorLines
        
        try {
            $this.Console.HideCursor()
            
            # Initial full render
            $this.RenderFull($searchText, $filteredRepos, $selectedIndex, $focusMode, $viewportStart, $pageSize, $allRepos.Count, $listStartLine)
            
            while ($running) {
                # Show cursor only when in input mode
                if ($focusMode -eq "input") {
                    $this.Console.ShowCursor()
                } else {
                    $this.Console.HideCursor()
                }
                
                # Read key
                $key = $this.Console.ReadKey()
                $keyCode = $key.VirtualKeyCode
                $keyChar = $key.Character
                
                # Handle Escape - context-aware
                if ($keyCode -eq [Constants]::KEY_ESCAPE -or $keyCode -eq [Constants]::KEY_ESC) {
                    if ($focusMode -eq "list") {
                        # Return to input
                        $focusMode = "input"
                        $this.RenderFull($searchText, $filteredRepos, $selectedIndex, $focusMode, $viewportStart, $pageSize, $allRepos.Count, $listStartLine)
                    } else {
                        # Exit search
                        $running = $false
                        $cancelled = $true
                    }
                    continue
                }
                
                # Handle Enter - select current item
                if ($keyCode -eq [Constants]::KEY_ENTER) {
                    if ($filteredRepos.Count -gt 0) {
                        $running = $false
                    }
                    continue
                }
                
                # Handle Tab - toggle focus
                if ($keyCode -eq [Constants]::KEY_TAB) {
                    if ($focusMode -eq "input" -and $filteredRepos.Count -gt 0) {
                        $focusMode = "list"
                    } else {
                        $focusMode = "input"
                    }
                    $this.RenderFull($searchText, $filteredRepos, $selectedIndex, $focusMode, $viewportStart, $pageSize, $allRepos.Count, $listStartLine)
                    continue
                }
                
                # Handle navigation
                if ($keyCode -eq [Constants]::KEY_DOWN_ARROW) {
                    if ($focusMode -eq "input" -and $filteredRepos.Count -gt 0) {
                        # Move from input to list
                        $focusMode = "list"
                        $this.RenderFull($searchText, $filteredRepos, $selectedIndex, $focusMode, $viewportStart, $pageSize, $allRepos.Count, $listStartLine)
                    } elseif ($focusMode -eq "list" -and $filteredRepos.Count -gt 0) {
                        $prevIndex = $selectedIndex
                        $prevViewport = $viewportStart
                        
                        # Navigate down in list
                        if ($selectedIndex -lt ($filteredRepos.Count - 1)) {
                            $selectedIndex++
                            # Scroll check
                            if ($selectedIndex -ge ($viewportStart + $pageSize)) {
                                $viewportStart = $selectedIndex - $pageSize + 1
                            }
                        } else {
                            # Wrap to top
                            $selectedIndex = 0
                            $viewportStart = 0
                        }
                        
                        # Render update
                        if ($viewportStart -ne $prevViewport) {
                            # Full list redraw needed
                            $this.RenderList($filteredRepos, $selectedIndex, $focusMode, $viewportStart, $pageSize, $listStartLine)
                        } else {
                            # Partial update - just the two affected lines
                            $this.UpdateListItem($filteredRepos, $prevIndex, $false, $viewportStart, $pageSize, $listStartLine)
                            $this.UpdateListItem($filteredRepos, $selectedIndex, $true, $viewportStart, $pageSize, $listStartLine)
                        }
                        $this.RenderFooter($selectedIndex, $filteredRepos.Count, $allRepos.Count, $focusMode, $listStartLine, $pageSize)
                    }
                    continue
                }
                
                if ($keyCode -eq [Constants]::KEY_UP_ARROW) {
                    if ($focusMode -eq "list" -and $filteredRepos.Count -gt 0) {
                        $prevIndex = $selectedIndex
                        $prevViewport = $viewportStart
                        
                        if ($selectedIndex -gt 0) {
                            $selectedIndex--
                            # Scroll check
                            if ($selectedIndex -lt $viewportStart) {
                                $viewportStart = $selectedIndex
                            }
                        } else {
                            # Move back to input when at top
                            $focusMode = "input"
                            $this.RenderFull($searchText, $filteredRepos, $selectedIndex, $focusMode, $viewportStart, $pageSize, $allRepos.Count, $listStartLine)
                            continue
                        }
                        
                        # Render update
                        if ($viewportStart -ne $prevViewport) {
                            $this.RenderList($filteredRepos, $selectedIndex, $focusMode, $viewportStart, $pageSize, $listStartLine)
                        } else {
                            $this.UpdateListItem($filteredRepos, $prevIndex, $false, $viewportStart, $pageSize, $listStartLine)
                            $this.UpdateListItem($filteredRepos, $selectedIndex, $true, $viewportStart, $pageSize, $listStartLine)
                        }
                        $this.RenderFooter($selectedIndex, $filteredRepos.Count, $allRepos.Count, $focusMode, $listStartLine, $pageSize)
                    }
                    continue
                }
                
                # Handle text input (only in input mode)
                if ($focusMode -eq "input") {
                    $needsFilterUpdate = $false
                    
                    # Backspace
                    if ($keyCode -eq [Constants]::KEY_BACKSPACE) {
                        if ($searchText.Length -gt 0) {
                            $searchText = $searchText.Substring(0, $searchText.Length - 1)
                            $needsFilterUpdate = $true
                        }
                    }
                    # Regular character input (letters, numbers, common chars)
                    elseif ($keyChar -match '[a-zA-Z0-9\s\-_\.]') {
                        $searchText += $keyChar
                        $needsFilterUpdate = $true
                    }
                    
                    if ($needsFilterUpdate) {
                        $filteredRepos = $this.SearchService.FilterRepositories($allRepos, $searchText)
                        $selectedIndex = 0
                        $viewportStart = 0
                        $this.RenderFull($searchText, $filteredRepos, $selectedIndex, $focusMode, $viewportStart, $pageSize, $allRepos.Count, $listStartLine)
                    }
                }
            }
        }
        finally {
            $this.Console.HideCursor()
        }
        
        # Prepare result
        $selectedRepo = $null
        $originalIndex = -1
        
        if (-not $cancelled -and $filteredRepos.Count -gt 0 -and $selectedIndex -lt $filteredRepos.Count) {
            $selectedRepo = $filteredRepos[$selectedIndex]
            $originalIndex = $this.SearchService.FindOriginalIndex($allRepos, $selectedRepo)
        }
        
        return @{
            SelectedRepo  = $selectedRepo
            SelectedIndex = $originalIndex
            Cancelled     = $cancelled
        }
    }
    
    #region Rendering Methods
    
    <#
    .SYNOPSIS
        Full screen render
    #>
    hidden [void] RenderFull([string]$searchText, [array]$filteredRepos, [int]$selectedIndex, [string]$focusMode, [int]$viewportStart, [int]$pageSize, [int]$totalCount, [int]$listStartLine) {
        $this.Console.ClearScreen()
        
        # Header (3 lines)
        $title = $this.GetLoc("Search.Title", "SEARCH REPOSITORIES")
        $this.Renderer.RenderHeader($title)
        
        # Search input (3 lines: label+input, blank)
        $this.RenderSearchInput($searchText, ($focusMode -eq "input"))
        $this.Console.NewLine()
        
        # Results count (2 lines)
        $resultCount = $filteredRepos.Count
        $countText = $this.GetLoc("Search.ResultCount", "{0} of {1} repositories") -f $resultCount, $totalCount
        $this.Console.WriteLineColored("  $countText", [Constants]::ColorHint)
        $this.Console.NewLine()
        
        # Separator before list
        $this.Console.WriteSeparator("-", [Constants]::UIWidth, [Constants]::ColorSeparator)
        
        # Render list
        $this.RenderList($filteredRepos, $selectedIndex, $focusMode, $viewportStart, $pageSize, $listStartLine)
        
        # Footer
        $this.RenderFooter($selectedIndex, $filteredRepos.Count, $totalCount, $focusMode, $listStartLine, $pageSize)
    }
    
    <#
    .SYNOPSIS
        Renders the search input field
    #>
    hidden [void] RenderSearchInput([string]$searchText, [bool]$hasFocus) {
        $label = $this.GetLoc("Search.Label", "Search")
        $placeholder = $this.GetLoc("Search.Placeholder", "Type to filter...")
        
        $focusIndicator = if ($hasFocus) { ">" } else { " " }
        $inputColor = if ($hasFocus) { [Constants]::ColorSelected } else { [Constants]::ColorMenuText }
        
        $this.Console.WriteColored("  $focusIndicator ", $inputColor)
        $this.Console.WriteColored("$label`: ", [Constants]::ColorLabel)
        
        if ([string]::IsNullOrEmpty($searchText)) {
            $this.Console.WriteLineColored($placeholder, [Constants]::ColorHint)
        } else {
            $this.Console.WriteLineColored($searchText, [Constants]::ColorValue)
        }
    }
    
    <#
    .SYNOPSIS
        Renders the results list with viewport
    #>
    hidden [void] RenderList([array]$repos, [int]$selectedIndex, [string]$focusMode, [int]$viewportStart, [int]$pageSize, [int]$startLine) {
        $listHasFocus = ($focusMode -eq "list")
        $total = $repos.Count
        
        for ($i = 0; $i -lt $pageSize; $i++) {
            $currentLine = $startLine + $i
            $this.Console.SetCursorPosition(0, $currentLine)
            $this.Console.ClearCurrentLine()
            
            $repoIndex = $viewportStart + $i
            if ($repoIndex -lt $total) {
                $repo = $repos[$repoIndex]
                $isSelected = ($repoIndex -eq $selectedIndex) -and $listHasFocus
                $this.RenderListItem($repo, $isSelected, $listHasFocus)
            }
        }
    }
    
    <#
    .SYNOPSIS
        Updates a single list item (partial render)
    #>
    hidden [void] UpdateListItem([array]$repos, [int]$repoIndex, [bool]$isSelected, [int]$viewportStart, [int]$pageSize, [int]$startLine) {
        # Check if index is in viewport
        if ($repoIndex -lt $viewportStart -or $repoIndex -ge ($viewportStart + $pageSize)) {
            return
        }
        
        $lineOffset = $repoIndex - $viewportStart
        $currentLine = $startLine + $lineOffset
        
        $this.Console.SetCursorPosition(0, $currentLine)
        $this.Console.ClearCurrentLine()
        
        if ($repoIndex -lt $repos.Count) {
            $repo = $repos[$repoIndex]
            $this.RenderListItem($repo, $isSelected, $true)
        }
    }
    
    <#
    .SYNOPSIS
        Renders a single list item
    #>
    hidden [void] RenderListItem([object]$repo, [bool]$isSelected, [bool]$listHasFocus) {
        $prefix = if ($isSelected) { ">" } else { " " }
        
        if ($isSelected) {
            $nameColor = [Constants]::ColorSelected
        } else {
            $nameColor = [Constants]::ColorMenuText
        }
        
        # Build display
        $this.Console.WriteColored("  $prefix ", $nameColor)
        
        # Favorite indicator
        if ($repo.IsFavorite) {
            $this.Console.WriteColored("$([Constants]::FavoriteSymbol) ", [Constants]::ColorFavorite)
        } else {
            $this.Console.Write("  ")
        }
        
        # Repo name
        $this.Console.WriteColored($repo.Name, $nameColor)
        
        # Alias if exists
        if ($repo.HasAlias -and $null -ne $repo.AliasInfo) {
            $aliasText = " [$($repo.AliasInfo.Alias)]"
            $this.Console.WriteColored($aliasText, $repo.AliasInfo.Color)
        }
    }
    
    <#
    .SYNOPSIS
        Renders the footer with position info and hints
    #>
    hidden [void] RenderFooter([int]$selectedIndex, [int]$filteredCount, [int]$totalCount, [string]$focusMode, [int]$listStartLine, [int]$pageSize) {
        $footerLine = $listStartLine + $pageSize
        $this.Console.SetCursorPosition(0, $footerLine)
        
        # Clear footer area (4 lines)
        for ($i = 0; $i -lt $this.FooterLines; $i++) {
            $this.Console.ClearCurrentLine()
            $this.Console.SetCursorPosition(0, $footerLine + $i)
        }
        $this.Console.SetCursorPosition(0, $footerLine)
        
        # Separator
        $this.Console.WriteSeparator("=", [Constants]::UIWidth, [Constants]::ColorSeparator)
        
        # Position info
        if ($filteredCount -gt 0) {
            $currentPos = $selectedIndex + 1
            $this.Console.WriteColored("  Item: ", [Constants]::ColorLabel)
            $this.Console.WriteColored("$currentPos/$filteredCount", [Constants]::ColorValue)
            $this.Console.WriteColored(" | Filtered: ", [Constants]::ColorLabel)
            $this.Console.WriteLineColored("$filteredCount of $totalCount", [Constants]::ColorHint)
        } else {
            $noResults = $this.GetLoc("Search.NoResults", "No repositories found")
            $this.Console.WriteLineColored("  $noResults", [Constants]::ColorWarning)
        }
        
        # Hints
        $this.RenderHints($focusMode)
        
        # Final separator
        $this.Console.WriteSeparator("=", [Constants]::UIWidth, [Constants]::ColorSeparator)
    }
    
    <#
    .SYNOPSIS
        Renders context-aware keyboard hints
    #>
    hidden [void] RenderHints([string]$focusMode) {
        if ($focusMode -eq "input") {
            $hint1 = $this.GetLoc("Search.Hint.Input", "Type to filter | Down/Tab=Go to list | Esc=Close")
            $this.Console.WriteLineColored("  $hint1", [Constants]::ColorHint)
        } else {
            $hint2 = $this.GetLoc("Search.Hint.List", "Up/Down=Navigate | Enter=Open | Up(top)/Tab=Back to search | Esc=Close")
            $this.Console.WriteLineColored("  $hint2", [Constants]::ColorHint)
        }
    }
    
    #endregion
}
