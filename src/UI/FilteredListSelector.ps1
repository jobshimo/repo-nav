<#
.SYNOPSIS
    FilteredListSelector - Generic interactive selector with filtering
    
.DESCRIPTION
    Reuses patterns from SearchView but for generic string lists.
    - SRP: Only responsible for rendering list and handling selection input
    - DIP: Depends on ConsoleHelper, UIRenderer
#>

class FilteredListSelector {
    [ConsoleHelper] $Console
    [UIRenderer] $Renderer
    [WindowSizeCalculator] $WindowCalculator
    
    # Layout constants
    [int] $HeaderLines = 3
    [int] $SearchInputLines = 3
    [int] $FooterLines = 4
    
    # State persistence for header navigation
    [int] $LastHeaderIndex = 0

    FilteredListSelector([ConsoleHelper]$console, [object]$renderer) {
        $this.Console = $console
        $this.Renderer = $renderer
        $this.WindowCalculator = [WindowSizeCalculator]::new()
    }
    
    hidden [int] CalculatePageSize([int]$headerOptionCount) {
        # Reserved: Header(3) + HeaderOptions(N) + Spacing(1) + Input(3) + Footer(4) + Padding(2)
        $reservedLines = $this.HeaderLines + $this.SearchInputLines + $this.FooterLines + 2 + $headerOptionCount + 1
        $windowHeight = $this.WindowCalculator.GetWindowHeight()
        $available = $windowHeight - $reservedLines
        
        if ($available -lt 3) { return 3 }
        if ($available -gt 20) { return 20 }
        return $available
    }
    
    # Returns a hashtable:
    # @{ Type = "Item"; Value = "SelectedString" }
    # @{ Type = "Header"; Value = "HeaderOption" }
    # $null if cancelled
    [object] ShowSelection([string]$title, [string[]]$items, [string]$prompt, [string[]]$headerOptions = @()) {
        if ($null -eq $items -or $items.Count -eq 0) {
            return $null
        }
        
        $searchText = ""
        $filteredItems = $items
        $selectedIndex = 0
        
        # Restore last header index or default to 0
        $headerIndex = if ($this.LastHeaderIndex -lt $headerOptions.Count) { $this.LastHeaderIndex } else { 0 }
        
        # Focus modes: "header", "input", "list"
        $focusMode = "input" 
        
        $running = $true
        $viewportStart = 0
        $pageSize = $this.CalculatePageSize($headerOptions.Count)
        $result = $null
        
        try {
            $this.Console.HideCursor()
            
            # Initial Render
            $this.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $headerIndex, $focusMode, $viewportStart, $pageSize, $items.Count, $prompt, $headerOptions)
            
            while ($running) {
                 if ($focusMode -eq "input") {
                    # Calculate cursor X: indent (2) + prompt + ": " (2) + text
                    $cursorX = 2 + $prompt.Length + 2 + $searchText.Length
                    # Calculate cursor Y: HeaderLines + HeaderOptions + Spacing(1)
                    $cursorY = $this.HeaderLines + $headerOptions.Count + 1
                    
                    $this.Console.SetCursorPosition($cursorX, $cursorY)
                    $this.Console.ShowCursor()
                } else {
                    $this.Console.HideCursor()
                }
                
                $key = $this.Console.ReadKey()
                $keyCode = $key.VirtualKeyCode
                $keyChar = $key.Character
                
                # Esc
                if ($keyCode -eq [Constants]::KEY_ESCAPE -or $keyCode -eq [Constants]::KEY_ESC) {
                    if ($focusMode -eq "list" -or $focusMode -eq "header") {
                        $focusMode = "input"
                        $this.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $headerIndex, $focusMode, $viewportStart, $pageSize, $items.Count, $prompt, $headerOptions)
                    } else {
                        $running = $false
                    }
                    continue
                }
                
                # Enter
                 if ($keyCode -eq [Constants]::KEY_ENTER) {
                    if ($focusMode -eq "list" -and $filteredItems.Count -gt 0) {
                        $result = @{ Type = "Item"; Value = $filteredItems[$selectedIndex] }
                        $running = $false
                    }
                    elseif ($focusMode -eq "header" -and $headerOptions.Count -gt 0) {
                         $this.LastHeaderIndex = $headerIndex # Persist choice
                         $result = @{ Type = "Header"; Value = $headerOptions[$headerIndex] }
                         $running = $false
                    }
                    continue
                }
                
                # Tab (Cycle Input -> List -> Header -> Input ?)
                if ($keyCode -eq [Constants]::KEY_TAB) {
                    if ($focusMode -eq "input") {
                        if ($filteredItems.Count -gt 0) { $focusMode = "list" }
                        elseif ($headerOptions.Count -gt 0) { $focusMode = "header" }
                    } 
                    elseif ($focusMode -eq "list") {
                        if ($headerOptions.Count -gt 0) { $focusMode = "header" }
                        else { $focusMode = "input" }
                    }
                    elseif ($focusMode -eq "header") {
                        $focusMode = "input"
                    }
                    
                    $this.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $headerIndex, $focusMode, $viewportStart, $pageSize, $items.Count, $prompt, $headerOptions)
                    continue
                }
                
                # Arrows
                if ($keyCode -eq [Constants]::KEY_DOWN_ARROW) {
                    if ($focusMode -eq "header") {
                        if ($headerIndex -lt ($headerOptions.Count - 1)) {
                            $headerIndex++
                            $this.LastHeaderIndex = $headerIndex
                            $this.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $headerIndex, $focusMode, $viewportStart, $pageSize, $items.Count, $prompt, $headerOptions)
                        } else {
                            # Go to Input
                            $this.LastHeaderIndex = $headerIndex # Remember where we left off
                            $focusMode = "input"
                            $this.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $headerIndex, $focusMode, $viewportStart, $pageSize, $items.Count, $prompt, $headerOptions)
                        }
                    }
                    elseif ($focusMode -eq "input") {
                        if ($filteredItems.Count -gt 0) {
                            $focusMode = "list"
                            $selectedIndex = 0
                            $viewportStart = 0
                            $this.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $headerIndex, $focusMode, $viewportStart, $pageSize, $items.Count, $prompt, $headerOptions)
                        }
                    }
                    elseif ($focusMode -eq "list" -and $filteredItems.Count -gt 0) {
                        if ($selectedIndex -lt ($filteredItems.Count - 1)) {
                            $selectedIndex++
                            if ($selectedIndex -ge ($viewportStart + $pageSize)) {
                                $viewportStart = $selectedIndex - $pageSize + 1
                            }
                        } else {
                            $selectedIndex = 0
                            $viewportStart = 0
                        }
                        $this.RenderList($filteredItems, $selectedIndex, $focusMode, $viewportStart, $pageSize, $headerOptions.Count)
                    }
                    continue
                }
                
                if ($keyCode -eq [Constants]::KEY_UP_ARROW) {
                    if ($focusMode -eq "list") {
                         if ($selectedIndex -gt 0) {
                            $selectedIndex--
                            if ($selectedIndex -lt $viewportStart) {
                                $viewportStart = $selectedIndex
                            }
                            $this.RenderList($filteredItems, $selectedIndex, $focusMode, $viewportStart, $pageSize, $headerOptions.Count)
                        } else {
                            # Go to Input
                            $focusMode = "input"
                            $this.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $headerIndex, $focusMode, $viewportStart, $pageSize, $items.Count, $prompt, $headerOptions)
                        }
                    }
                    elseif ($focusMode -eq "input") {
                        if ($headerOptions.Count -gt 0) {
                            $focusMode = "header"
                            # Restore last header index
                            $headerIndex = if ($this.LastHeaderIndex -lt $headerOptions.Count) { $this.LastHeaderIndex } else { $headerOptions.Count - 1 }
                            
                            $this.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $headerIndex, $focusMode, $viewportStart, $pageSize, $items.Count, $prompt, $headerOptions)
                        }
                    }
                    elseif ($focusMode -eq "header") {
                        if ($headerIndex -gt 0) {
                            $headerIndex--
                            $this.LastHeaderIndex = $headerIndex
                            $this.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $headerIndex, $focusMode, $viewportStart, $pageSize, $items.Count, $prompt, $headerOptions)
                        }
                    }
                    continue
                }
                
                # Input
                 if ($focusMode -eq "input") {
                    $needsUpdate = $false
                    if ($keyCode -eq [Constants]::KEY_BACKSPACE) {
                        if ($searchText.Length -gt 0) {
                            $searchText = $searchText.Substring(0, $searchText.Length - 1)
                            $needsUpdate = $true
                        }
                    } elseif ($keyChar -match '[a-zA-Z0-9\s\-\._\/]') {
                        $searchText += $keyChar
                        $needsUpdate = $true
                    }
                    
                    if ($needsUpdate) {
                        $lowerSearch = $searchText.ToLower()
                        $filteredItems = @($items | Where-Object { $_.ToLower().Contains($lowerSearch) })
                        $selectedIndex = 0
                        $viewportStart = 0
                        $this.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $headerIndex, $focusMode, $viewportStart, $pageSize, $items.Count, $prompt, $headerOptions)
                    }
                 }
            }
        }
        finally {
            $this.Console.HideCursor()
        }
        
        return $result
    }
    
    hidden [void] RenderFull([string]$title, [string]$searchText, [array]$items, [int]$selectedIndex, [int]$headerIndex, [string]$focusMode, [int]$viewportStart, [int]$pageSize, [int]$totalCount, [string]$prompt, [string[]]$headerOptions) {
        $this.Console.HideCursor()
        $this.Console.ClearScreen()
        
        $this.Renderer.RenderHeader($title)
        
        # Reader Header Options
        if ($headerOptions.Count -gt 0) {
            for ($i = 0; $i -lt $headerOptions.Count; $i++) {
                 $isHeaderSelected = ($focusMode -eq "header" -and $i -eq $headerIndex)
                 $hPrefix = if ($isHeaderSelected) { "> " } else { "  " } # Same indent as input
                 $hColor = if ($isHeaderSelected) { [Constants]::ColorSelected } else { [Constants]::ColorMenuText }
                 
                 $this.Console.WriteColored("  $hPrefix", $hColor)
                 $this.Console.WriteLineColored($headerOptions[$i], $hColor)
            }
            # Add spacing after header options
            $this.Console.NewLine()
        }
        
        # Search Input
        $focusIndicator = if ($focusMode -eq "input") { ">" } else { " " }
        $inputColor = if ($focusMode -eq "input") { [Constants]::ColorSelected } else { [Constants]::ColorMenuText }
        
        $this.Console.WriteColored("  $focusIndicator ", $inputColor)
        $this.Console.WriteColored("$prompt`: ", [Constants]::ColorLabel)
        
        if ([string]::IsNullOrEmpty($searchText)) {
            $this.Console.WriteLineColored("Type to filter...", [Constants]::ColorHint)
        } else {
            $this.Console.WriteLineColored($searchText, [Constants]::ColorValue)
        }
        $this.Console.NewLine()
        
        $countText = "{0} of {1} items" -f $items.Count, $totalCount
        $this.Console.WriteLineColored("  $countText", [Constants]::ColorHint)
        $this.Console.NewLine()
        
        $this.Console.WriteSeparator("-", [Constants]::UIWidth, [Constants]::ColorSeparator)
        
        $this.RenderList($items, $selectedIndex, $focusMode, $viewportStart, $pageSize, $headerOptions.Count)
        
        # Footer
        # HeaderLines(3) + HeaderOptions(N) + Spacing(1) + Input(3) + Footer(4) + Padding(2)
        # List starts at: 3 + N + 1 + 1 + 1 + 1 + 1 = 8 + N
        $listEnd = $this.HeaderLines + $headerOptions.Count + 1 + $this.SearchInputLines + 2 + 1 + $pageSize
        $this.Console.SetCursorPosition(0, $listEnd)
        $this.Console.WriteSeparator("=", [Constants]::UIWidth, [Constants]::ColorSeparator)
        $this.Console.WriteLineColored("  Enter to select | Esc to cancel", [Constants]::ColorHint)
    }
    
    hidden [void] RenderList([array]$items, [int]$selectedIndex, [string]$focusMode, [int]$viewportStart, [int]$pageSize, [int]$headerOptionCount) {
        # Calc start line
        # Header (3)
        # Options (count)
        # Spacing (1)
        # Input line (1)
        # Count line (1)
        # Blank line (1)
        # Separator (1)
        # Total: 3 + count + 1 + 1 + 1 + 1 + 1 = 8 + count
        
        $startLine = 8 + $headerOptionCount
        
        for ($i = 0; $i -lt $pageSize; $i++) {
            $this.Console.SetCursorPosition(0, $startLine + $i)
            $this.Console.ClearCurrentLine()
            
            $itemIndex = $viewportStart + $i
            if ($itemIndex -lt $items.Count) {
                $item = $items[$itemIndex]
                $isSelected = ($itemIndex -eq $selectedIndex) -and ($focusMode -eq "list")
                
                $prefix = if ($isSelected) { ">" } else { " " }
                $color = if ($isSelected) { [Constants]::ColorSelected } else { [Constants]::ColorMenuText }
                
                $this.Console.WriteColored("  $prefix ", $color)
                $this.Console.WriteLineColored($item, $color)
            }
        }
    }
}

