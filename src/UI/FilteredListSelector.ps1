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
        # Reserved: Header(3) + HeaderLines (now just 1 line if horizontal) + Spacing(1) + Input(3) + Footer(4) + Padding(2)
        # Assuming horizontal options take 1 line (can wrap if needed but let's assume 1 for simple flows)
        $optsHeight = if ($headerOptionCount -gt 0) { 1 } else { 0 }
        
        $reservedLines = $this.HeaderLines + $this.SearchInputLines + $this.FooterLines + 2 + $optsHeight + 1
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
    [object] ShowSelection([string]$title, [string[]]$items, [hashtable]$options) {
        if ($null -eq $items -or $items.Count -eq 0) {
            return $null
        }
        
        # Unpack options with defaults
        $prompt = if ($options.ContainsKey('Prompt')) { $options['Prompt'] } else { "Filter" }
        $headerOptions = if ($options.ContainsKey('HeaderOptions')) { $options['HeaderOptions'] } else { @() }
        $currentItem = if ($options.ContainsKey('CurrentItem')) { $options['CurrentItem'] } else { $null }
        $currentMarker = if ($options.ContainsKey('CurrentMarker')) { $options['CurrentMarker'] } else { "(current)" }
        $initialIndex = if ($options.ContainsKey('InitialIndex')) { [int]$options['InitialIndex'] } else { 0 }
        $statusMessage = if ($options.ContainsKey('StatusMessage')) { $options['StatusMessage'] } else { $null }
        $statusColor = if ($options.ContainsKey('StatusColor')) { $options['StatusColor'] } else { [ConsoleColor]::Gray }
        
        $searchText = ""
        $filteredItems = $items
        
        # Initialize selection and viewport
        $selectedIndex = if ($initialIndex -ge 0 -and $initialIndex -lt $items.Count) { $initialIndex } else { 0 }
        $pageSize = $this.CalculatePageSize($headerOptions.Count)
        
        $viewportStart = 0
        if ($selectedIndex -ge $pageSize) {
            $viewportStart = $selectedIndex - $pageSize + 1
        }
        
        # Restore last header index or default to 0
        $headerIndex = if ($this.LastHeaderIndex -lt $headerOptions.Count) { $this.LastHeaderIndex } else { 0 }
        
        # Focus modes: "header", "input", "list"
        # If we have an initial index, focus list? Or keep input default?
        # User wants "se quede seleccionado donde esta".
        $focusMode = if ($initialIndex -ge 0) { "list" } else { "input" }
        
        $running = $true
        $result = $null
        
        try {
            $this.Console.HideCursor()
            
            # Initial Render - Clear screen once
            $this.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $headerIndex, $focusMode, $viewportStart, $pageSize, $items.Count, $prompt, $headerOptions, $true, $currentItem, $currentMarker, $statusMessage, $statusColor)
            
            while ($running) {
                 if ($focusMode -eq "input") {
                    # Calculate cursor X: indent (4 for "  > ") + prompt + ": " (2) + text
                    $cursorX = 4 + $prompt.Length + 2 + $searchText.Length
                    # Calculate cursor Y: 
                    # Header(3) + HeaderOptions(1 if any) + Spacing(1)
                    $hLines = if ($headerOptions.Count -gt 0) { 1 } else { 0 }
                    $cursorY = $this.HeaderLines + $hLines + 1
                    
                    $this.Console.SetCursorPosition($cursorX, $cursorY)
                    $this.Console.ShowCursor()
                } else {
                    $this.Console.HideCursor()
                }
                
                $key = $this.Console.ReadKey()
                $keyCode = $key.VirtualKeyCode
                $keyChar = $key.Character
                
                # Clear Status Message on first keypress if it exists?
                # For now let it stay until screen redraw or maybe we want to keep it?
                # User says "aparezca el cartel... pero se quede seleccionado". 
                # Usually status messages are transient. Let's clear it from args for next render?
                # Actually, RenderFull clears the line before writing footer. So if we pass $null next time, it disappears.
                # But we only call RenderFull on updates.
                # Let's keep it simple: It stays until next full update updates the Footer area.
                
                # Esc
                if ($keyCode -eq [Constants]::KEY_ESCAPE -or $keyCode -eq [Constants]::KEY_ESC) {
                    if ($focusMode -eq "list" -or $focusMode -eq "header") {
                        $focusMode = "input"
                        $this.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $headerIndex, $focusMode, $viewportStart, $pageSize, $items.Count, $prompt, $headerOptions, $false, $currentItem, $currentMarker, $null, $statusColor)
                    } else {
                        $running = $false
                    }
                    continue
                }
                
                # Enter
                 if ($keyCode -eq [Constants]::KEY_ENTER) {
                    if ($focusMode -eq "list" -and $filteredItems.Count -gt 0) {
                        $result = @{ Type = "Item"; Value = $filteredItems[$selectedIndex]; Index = $selectedIndex }
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
                    
                    $this.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $headerIndex, $focusMode, $viewportStart, $pageSize, $items.Count, $prompt, $headerOptions, $false, $currentItem, $currentMarker, $null, $statusColor)
                    continue
                }
                
                # Left / Right (Header Navigation)
                if ($focusMode -eq "header") {
                    if ($keyCode -eq [Constants]::KEY_LEFT_ARROW) {
                        if ($headerIndex -gt 0) {
                            $headerIndex--
                            $this.LastHeaderIndex = $headerIndex
                            $this.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $headerIndex, $focusMode, $viewportStart, $pageSize, $items.Count, $prompt, $headerOptions, $false, $currentItem, $currentMarker, $null, $statusColor)
                        }
                        continue
                    }
                     if ($keyCode -eq [Constants]::KEY_RIGHT_ARROW) {
                        if ($headerIndex -lt ($headerOptions.Count - 1)) {
                            $headerIndex++
                            $this.LastHeaderIndex = $headerIndex
                            $this.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $headerIndex, $focusMode, $viewportStart, $pageSize, $items.Count, $prompt, $headerOptions, $false, $currentItem, $currentMarker, $null, $statusColor)
                        }
                        continue
                    }
                }
                
                # Down Arrow
                if ($keyCode -eq [Constants]::KEY_DOWN_ARROW) {
                    if ($focusMode -eq "header") {
                        # Down goes to input
                        $this.LastHeaderIndex = $headerIndex # Remember
                        $focusMode = "input"
                        $this.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $headerIndex, $focusMode, $viewportStart, $pageSize, $items.Count, $prompt, $headerOptions, $false, $currentItem, $currentMarker, $null, $statusColor)
                    }
                    elseif ($focusMode -eq "input") {
                        if ($filteredItems.Count -gt 0) {
                            $focusMode = "list"
                            $selectedIndex = 0
                            $viewportStart = 0
                            $this.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $headerIndex, $focusMode, $viewportStart, $pageSize, $items.Count, $prompt, $headerOptions, $false, $currentItem, $currentMarker, $null, $statusColor)
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
                        # RenderList is already optimized
                        $this.RenderList($filteredItems, $selectedIndex, $focusMode, $viewportStart, $pageSize, $headerOptions.Count, $currentItem, $currentMarker)
                    }
                    continue
                }
                
                # Up Arrow
                if ($keyCode -eq [Constants]::KEY_UP_ARROW) {
                    if ($focusMode -eq "list") {
                         if ($selectedIndex -gt 0) {
                            $selectedIndex--
                            if ($selectedIndex -lt $viewportStart) {
                                $viewportStart = $selectedIndex
                            }
                            $this.RenderList($filteredItems, $selectedIndex, $focusMode, $viewportStart, $pageSize, $headerOptions.Count, $currentItem, $currentMarker)
                        } else {
                            # Go to Input
                            $focusMode = "input"
                            $this.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $headerIndex, $focusMode, $viewportStart, $pageSize, $items.Count, $prompt, $headerOptions, $false, $currentItem, $currentMarker, $null, $statusColor)
                        }
                    }
                    elseif ($focusMode -eq "input") {
                        if ($headerOptions.Count -gt 0) {
                            $focusMode = "header"
                            # Restore last header index
                            $headerIndex = if ($this.LastHeaderIndex -lt $headerOptions.Count) { $this.LastHeaderIndex } else { 0 }
                            
                            $this.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $headerIndex, $focusMode, $viewportStart, $pageSize, $items.Count, $prompt, $headerOptions, $false, $currentItem, $currentMarker, $null, $statusColor)
                        }
                    }
                    elseif ($focusMode -eq "header") {
                        # Up from header? Currently nothing / clamp
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
                        $this.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $headerIndex, $focusMode, $viewportStart, $pageSize, $items.Count, $prompt, $headerOptions, $false, $currentItem, $currentMarker, $null, $statusColor)
                    }
                 }
            }
        }
        finally {
            $this.Console.HideCursor()
        }
        
        return $result
    }
    
    hidden [void] RenderFull([string]$title, [string]$searchText, [array]$items, [int]$selectedIndex, [int]$headerIndex, [string]$focusMode, [int]$viewportStart, [int]$pageSize, [int]$totalCount, [string]$prompt, [string[]]$headerOptions, [bool]$clearScreen, [string]$currentItem, [string]$currentMarker, [string]$statusMessage, [ConsoleColor]$statusColor) {
        $this.Console.HideCursor()
        
        if ($clearScreen) {
            $this.Console.ClearScreen()
        } else {
            $this.Console.SetCursorPosition(0, 0)
        }
        
        $this.Renderer.RenderHeader($title)
        
        # Render Header Options (Horizontal)
        if ($headerOptions.Count -gt 0) {
            
            # Ensure line is clean before writing
            if (-not $clearScreen) { $this.Console.ClearCurrentLine() }
            
            # Start margin
            $this.Console.WriteColored("  ", [Constants]::ColorMenuText)
            
            for ($i = 0; $i -lt $headerOptions.Count; $i++) {
                 $isHeaderSelected = ($focusMode -eq "header" -and $i -eq $headerIndex)
                 $opt = $headerOptions[$i]
                 
                 $currentOpt = if ($isHeaderSelected) { " > $opt " } else { "   $opt " }
                 $hColor = if ($isHeaderSelected) { [Constants]::ColorSelected } else { [Constants]::ColorMenuText }
                 
                 $this.Console.WriteColored($currentOpt, $hColor)
                 
                 # Spacing between items
                 $this.Console.WriteColored("  ", [Constants]::ColorMenuText)
            }
            # Add spacing after header options
            $this.Console.NewLine()
            $this.Console.NewLine()
        }
        
        # Search Input
        if (-not $clearScreen) { $this.Console.ClearCurrentLine() }
        
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
        
        if (-not $clearScreen) { $this.Console.ClearCurrentLine() }
        $countText = "{0} of {1} items" -f $items.Count, $totalCount
        $this.Console.WriteLineColored("  $countText", [Constants]::ColorHint)
        $this.Console.NewLine()
        
        if (-not $clearScreen) { $this.Console.ClearCurrentLine() }
        $this.Console.WriteSeparator("-", [Constants]::UIWidth, [Constants]::ColorSeparator)
        
        $this.RenderList($items, $selectedIndex, $focusMode, $viewportStart, $pageSize, $headerOptions.Count, $currentItem, $currentMarker)
        
        # Footer
        # HeaderLines(3) + HeaderOptions(1) + Spacing(1) + Input(3) + Footer(4) + Padding(2)
        $hLines = if ($headerOptions.Count -gt 0) { 1 } else { 0 }
        
        $listEnd = $this.HeaderLines + $hLines + 1 + $this.SearchInputLines + 2 + 1 + $pageSize
        $this.Console.SetCursorPosition(0, $listEnd)
        
        if (-not $clearScreen) { $this.Console.ClearCurrentLine() }
        $this.Console.WriteSeparator("=", [Constants]::UIWidth, [Constants]::ColorSeparator)
        
        if (-not $clearScreen) { $this.Console.ClearCurrentLine() }
        
        if (-not [string]::IsNullOrEmpty($statusMessage)) {
             $this.Console.WriteColored("  $statusMessage", $statusColor)
             # Clear rest of line logic if needed
        } else {
             $this.Console.WriteLineColored("  Enter to select | Esc to cancel", [Constants]::ColorHint)
        }
    }
    
    hidden [void] RenderList([array]$items, [int]$selectedIndex, [string]$focusMode, [int]$viewportStart, [int]$pageSize, [int]$headerOptionCount, [string]$currentItem, [string]$currentMarker) {
        # Calc start line
        # Header (3)
        # Options (1 line horizontal)
        # Spacing (1)
        # Input line (1)
        # Count line (1)
        # Blank line (1)
        # Separator (1)
        # Total: 3 + 1 (if options) + 1 + 1 + 1 + 1 + 1 = 9 (if options), 7 (if no options)
        
        $hLines = if ($headerOptionCount -gt 0) { 1 } else { 0 }
        $startLine = $this.HeaderLines + $hLines + 1 + 2 + 1 + 1 # Header + Opts + Spacing + Input(1) + Count(1) ... checking RenderFull
        # Let's count calls in RenderFull:
        # Header(3)
        # Options(1) + NL(1) = 2 lines if opts
        # Input(1)
        # Count(1)
        # NL(1)
        # Sep(1)
        # So start is: 3 + (2 if opts) + 1 + 1 + 1 + 1 = 9 if opts.
        
        $offset = if ($headerOptionCount -gt 0) { 2 } else { 0 }
        $startLine = 3 + $offset + 4 # 7 + offset
        
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
                $this.Console.WriteColored($item, $color)
                
                if ($null -ne $currentItem -and $item -eq $currentItem) {
                    $this.Console.WriteColored(" $currentMarker", [Constants]::ColorHint)
                }
                
                $this.Console.NewLine()
            }
        }
    }
}

