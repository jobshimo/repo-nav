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
    [ViewportManager] $Viewport
    
    # Layout constants
    [int] $HeaderLines = 3          # Title separator lines
    [int] $SearchInputLines = 1     # Search label + input (no blank line)
    [int] $CounterLines = 0         # Result count removed
    [int] $SeparatorLines = 1       # Separator before list
    [int] $FooterLines = 4          # Separator + hints + blank + separator
    
    # Constructor with dependency injection
    SearchView([ConsoleHelper]$console, [UIRenderer]$renderer, [LocalizationService]$localizationService) {
        $this.Console = $console
        $this.Renderer = $renderer
        $this.SearchService = [SearchService]::new()
        $this.LocalizationService = $localizationService
        $this.WindowCalculator = [WindowSizeCalculator]::new()
        $this.Viewport = [ViewportManager]::new()
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
        if ($available -lt 1) { return 1 }
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
        $focusMode = "input"  # "input" or "list"
        $running = $true
        $cancelled = $false
        
        # Check Header Preference
        $showHeaders = $this.Renderer.ShouldShowHeaders()
        
        # Adjust layout based on preference
        $headerOffset = if ($showHeaders) { 3 } else { 0 }
        $this.HeaderLines = $headerOffset
        
        # Calculate line positions
        $listStartLine = $this.HeaderLines + $this.SearchInputLines + $this.CounterLines + $this.SeparatorLines
        
        # Initialize Viewport
        $pageSize = $this.CalculatePageSize()
        $initialIndex = 0
        if ($null -ne $currentRepo) {
            $initialIndex = $this.SearchService.FindRepositoryIndex($filteredRepos, $currentRepo)
            if ($initialIndex -eq -1) { $initialIndex = 0 }
        }
        $this.Viewport.Initialize($filteredRepos.Count, $pageSize, $initialIndex)
        
        try {
            $this.Console.HideCursor()
            
            # Initial full render
            $this.RenderFull($searchText, $filteredRepos, $focusMode, $allRepos.Count, $listStartLine)
            
            # Get label for cursor position calculation
            $searchLabel = $this.GetLoc("Search.Label", "Search")
            
            while ($running) {
                # Manage cursor visibility based on focus mode
                if ($focusMode -eq "input") {
                    # Position cursor at end of search input
                    # Format: "  > " (4 chars) + label + ": " (2 chars) + text
                    $cursorX = 4 + $searchLabel.Length + 2 + $searchText.Length
                    $cursorY = $this.HeaderLines # Input is immediately after header
                    $this.Console.SetCursorPosition($cursorX, $cursorY)
                    $this.Console.ShowCursor()
                } else {
                    $this.Console.HideCursor()
                }
                
                # Update Page Size if window resized (simple check)
                $newPageSize = $this.CalculatePageSize()
                if ($newPageSize -ne $this.Viewport.PageSize) {
                    $this.Viewport.SetPageSize($newPageSize)
                    $this.RenderFull($searchText, $filteredRepos, $focusMode, $allRepos.Count, $listStartLine)
                }
                
                # Read key
                $key = $this.Console.ReadKey()
                $keyCode = $key.VirtualKeyCode
                $keyChar = $key.Character
                
                # Handle Escape - context-aware
                if ($keyCode -eq [Constants]::KEY_ESCAPE -or $keyCode -eq [Constants]::KEY_ESC) {
                    if ($focusMode -eq "list") {
                        # Return to input - only update input line
                        $focusMode = "input"
                        $this.UpdateSearchInput($searchText, $true)
                        # Re-render list to remove focus highlight
                        $this.RenderList($filteredRepos, $focusMode, $listStartLine)
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
                        # Switch to list
                        $focusMode = "list"
                        $this.UpdateSearchInput($searchText, $false)
                        $this.RenderList($filteredRepos, $focusMode, $listStartLine)
                    } else {
                        # Switch to input
                        $focusMode = "input"
                        $this.UpdateSearchInput($searchText, $true)
                        $this.RenderList($filteredRepos, $focusMode, $listStartLine)
                    }
                    $this.RenderFooter($filteredRepos.Count, $allRepos.Count, $focusMode, $listStartLine)
                    continue
                }
                
                # Handle navigation
                if ($keyCode -eq [Constants]::KEY_DOWN_ARROW) {
                    if ($focusMode -eq "input" -and $filteredRepos.Count -gt 0) {
                        # Move from input to list
                        $focusMode = "list"
                        $this.Viewport.MoveToStart()
                        $this.UpdateSearchInput($searchText, $false)
                        $this.RenderList($filteredRepos, $focusMode, $listStartLine)
                        $this.RenderFooter($filteredRepos.Count, $allRepos.Count, $focusMode, $listStartLine)
                    } elseif ($focusMode -eq "list" -and $filteredRepos.Count -gt 0) {
                        $prevIndex = $this.Viewport.SelectedIndex
                        $prevViewport = $this.Viewport.ViewportStart
                        
                        $this.Viewport.MoveDown()
                        
                        if ($this.Viewport.ViewportStart -ne $prevViewport) {
                             $this.RenderList($filteredRepos, $focusMode, $listStartLine)
                        } else {
                             $this.UpdateListItem($filteredRepos, $prevIndex, $false, $listStartLine)
                             $this.UpdateListItem($filteredRepos, $this.Viewport.SelectedIndex, $true, $listStartLine)
                        }
                        $this.RenderFooter($filteredRepos.Count, $allRepos.Count, $focusMode, $listStartLine)
                    }
                    continue
                }
                
                if ($keyCode -eq [Constants]::KEY_UP_ARROW) {
                    if ($focusMode -eq "list" -and $filteredRepos.Count -gt 0) {
                        $prevIndex = $this.Viewport.SelectedIndex
                        $prevViewport = $this.Viewport.ViewportStart
                        
                        if ($this.Viewport.SelectedIndex -eq 0) {
                             # Move back to input when at top
                             $focusMode = "input"
                             $this.UpdateSearchInput($searchText, $true)
                             $this.RenderList($filteredRepos, $focusMode, $listStartLine)
                             $this.RenderFooter($filteredRepos.Count, $allRepos.Count, $focusMode, $listStartLine)
                             continue
                        }

                        $this.Viewport.MoveUp()
                        
                        if ($this.Viewport.ViewportStart -ne $prevViewport) {
                             $this.RenderList($filteredRepos, $focusMode, $listStartLine)
                        } else {
                             $this.UpdateListItem($filteredRepos, $prevIndex, $false, $listStartLine)
                             $this.UpdateListItem($filteredRepos, $this.Viewport.SelectedIndex, $true, $listStartLine)
                        }
                        $this.RenderFooter($filteredRepos.Count, $allRepos.Count, $focusMode, $listStartLine)
                    }
                    continue
                }

                # Handle Home/End
                if ($keyCode -eq [Constants]::KEY_HOME) {
                    if ($focusMode -eq "list" -and $filteredRepos.Count -gt 0) {
                        $this.Viewport.MoveToStart()
                        $this.RenderList($filteredRepos, $focusMode, $listStartLine)
                        $this.RenderFooter($filteredRepos.Count, $allRepos.Count, $focusMode, $listStartLine)
                    }
                    continue
                }
                
                if ($keyCode -eq [Constants]::KEY_END) {
                    if ($focusMode -eq "list" -and $filteredRepos.Count -gt 0) {
                        $this.Viewport.MoveToEnd()
                        $this.RenderList($filteredRepos, $focusMode, $listStartLine)
                        $this.RenderFooter($filteredRepos.Count, $allRepos.Count, $focusMode, $listStartLine)
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
                        # Re-initialize viewport with new count, resetting selection to top
                        $this.Viewport.Initialize($filteredRepos.Count, $pageSize, 0)
                        $this.RenderFull($searchText, $filteredRepos, $focusMode, $allRepos.Count, $listStartLine)
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
        
        if (-not $cancelled -and $filteredRepos.Count -gt 0 -and $this.Viewport.SelectedIndex -lt $filteredRepos.Count) {
            $selectedRepo = $filteredRepos[$this.Viewport.SelectedIndex]
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
    hidden [void] RenderFull([string]$searchText, [array]$filteredRepos, [string]$focusMode, [int]$totalCount, [int]$listStartLine) {
        # Hide cursor during render to prevent flickering
        $this.Console.HideCursor()
        $this.Console.ClearScreen()
        
        # Header (3 lines)
        $title = $this.GetLoc("Search.Title", "SEARCH REPOSITORIES")
        $this.Renderer.RenderHeader($title)
        
        # Search input (1 line)
        $this.RenderSearchInput($searchText, ($focusMode -eq "input"))
        $this.Console.NewLine() # Add newline explicitly
        
        # Separator before list
        $this.Console.WriteSeparator("-", [Constants]::UIWidth, [Constants]::ColorSeparator)
        
        # Render list
        $this.RenderList($filteredRepos, $focusMode, $listStartLine)
        
        # Footer
        $this.RenderFooter($filteredRepos.Count, $totalCount, $focusMode, $listStartLine)
        
        # Keep cursor hidden after render - the main loop will show it if needed
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
            $this.Console.WriteColored($placeholder, [Constants]::ColorHint)
        } else {
            $this.Console.WriteColored($searchText, [Constants]::ColorValue)
        }
    }
    
    <#
    .SYNOPSIS
        Updates only the search input line (partial render)
    #>
    hidden [void] UpdateSearchInput([string]$searchText, [bool]$hasFocus) {
        # Hide cursor to prevent flickering
        $this.Console.HideCursor()
        
        $searchInputLine = $this.HeaderLines
        $this.Console.SetCursorPosition(0, $searchInputLine)
        $this.Console.SetCursorPosition(0, $searchInputLine)
        $this.RenderSearchInput($searchText, $hasFocus)
        $this.Console.ClearRestOfLine() # Ensure tail is cleared
    }
    
    <#
    .SYNOPSIS
        Renders the results list with viewport
    #>
    hidden [void] RenderList([array]$repos, [string]$focusMode, [int]$startLine) {
        # Hide cursor to prevent flickering during list update
        $this.Console.HideCursor()
        
        $listHasFocus = ($focusMode -eq "list")
        $total = $repos.Count
        
        $viewportStart = $this.Viewport.ViewportStart
        $pageSize = $this.Viewport.PageSize
        $selectedIndex = $this.Viewport.SelectedIndex
        
        for ($i = 0; $i -lt $pageSize; $i++) {
            $currentLine = $startLine + $i
            $this.Console.SetCursorPosition(0, $currentLine)
            $this.Console.SetCursorPosition(0, $currentLine)
            
            $repoIndex = $viewportStart + $i
            if ($repoIndex -lt $total) {
                $repo = $repos[$repoIndex]
                $isSelected = ($repoIndex -eq $selectedIndex) -and $listHasFocus
                $this.RenderListItem($repo, $isSelected, $listHasFocus)
            } else {
                 # Clear empty lines
                 $this.Console.ClearRestOfLine()
            }
        }
    }
    
    <#
    .SYNOPSIS
        Updates a single list item (partial render)
    #>
    hidden [void] UpdateListItem([array]$repos, [int]$repoIndex, [bool]$isSelected, [int]$startLine) {
        # Check if index is in viewport via ViewportManager
        if (-not $this.Viewport.IsVisible($repoIndex)) {
            return
        }
        
        $viewportStart = $this.Viewport.ViewportStart
        $lineOffset = $repoIndex - $viewportStart
        $currentLine = $startLine + $lineOffset
        
        $this.Console.SetCursorPosition(0, $currentLine)
        $this.Console.SetCursorPosition(0, $currentLine)
        
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
        
        # Ensure tail is cleared
        $this.Console.ClearRestOfLine()
    }
    
    <#
    .SYNOPSIS
        Renders the footer with position info and hints
    #>
    hidden [void] RenderFooter([int]$filteredCount, [int]$totalCount, [string]$focusMode, [int]$listStartLine) {
        # Hide cursor during footer render
        $this.Console.HideCursor()
        
        $footerLine = $listStartLine + $this.Viewport.PageSize
        $this.Console.SetCursorPosition(0, $footerLine)
        $this.Console.SetCursorPosition(0, $footerLine)
        
        # Separator
        $this.Console.WriteSeparator("=", [Constants]::UIWidth, [Constants]::ColorSeparator)
        
        # Position info
        if ($filteredCount -gt 0) {
            $currentPos = $this.Viewport.SelectedIndex + 1
            $lblItem = $this.GetLoc("UI.Label.Item", "Item")
            $lblFiltered = $this.GetLoc("UI.Label.Filtered", "Filtered")
            $lblOf = $this.GetLoc("UI.Label.Of", "of")
            
            $this.Console.WriteColored("  $lblItem`: ", [Constants]::ColorLabel)
            $this.Console.WriteColored("$currentPos/$filteredCount", [Constants]::ColorValue)
            $this.Console.WriteColored(" | $lblFiltered`: ", [Constants]::ColorLabel)
            $this.Console.WriteColored("$filteredCount $lblOf $totalCount", [Constants]::ColorHint)
            $this.Console.ClearRestOfLine()
            $this.Console.NewLine()
        } else {
            $noResults = $this.GetLoc("Search.NoResults", "No repositories found")
            $this.Console.WriteColored("  $noResults", [Constants]::ColorWarning)
            $this.Console.ClearRestOfLine()
            $this.Console.NewLine()
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
            $this.Console.WriteColored("  $hint1", [Constants]::ColorHint)
            $this.Console.ClearRestOfLine()
            $this.Console.NewLine()
        } else {
            $hint2 = $this.GetLoc("Search.Hint.List", "Up/Down=Navigate | Enter=Open | Up(top)/Tab=Back to search | Esc=Close")
            $this.Console.WriteColored("  $hint2", [Constants]::ColorHint)
            $this.Console.ClearRestOfLine()
            $this.Console.NewLine()
        }
    }
    
    #endregion
}
