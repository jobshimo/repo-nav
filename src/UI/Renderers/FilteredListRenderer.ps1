class FilteredListRenderer {
    [ConsoleHelper] $Console
    [UIRenderer] $UIRenderer

    FilteredListRenderer([ConsoleHelper]$console, [UIRenderer]$uiRenderer) {
        $this.Console = $console
        $this.UIRenderer = $uiRenderer
    }

    hidden [void] RenderFooter([int]$selectedIndex, [int]$filteredCount, [int]$totalCount, [string]$statusMessage, [ConsoleColor]$statusColor, [int]$footerStartLine, [bool]$clearScreen, [bool]$fastUpdate) {
        # Footer area: 4 lines
        $sep = "=" * [Constants]::UIWidth
        
        if (-not $fastUpdate) {
            for ($i = 0; $i -lt 4; $i++) {
                $this.Console.SetCursorPosition(0, $footerStartLine + $i)
                if (-not $clearScreen) { $this.Console.ClearCurrentLine() }
            }
        }
        
        # 1. Separator
        if (-not $fastUpdate) {
            $this.Console.SetCursorPosition(0, $footerStartLine)
            $this.Console.WriteColored($sep, [Constants]::ColorSeparator)
        }
        
        # 2. Counts (This changes on selection, so we redraw it)
        $this.Console.SetCursorPosition(0, $footerStartLine + 1)
        # Clear specific line if fast update to ensure no artifacts
        if ($fastUpdate) { $this.Console.ClearCurrentLine() }
        
        if ($filteredCount -gt 0) {
            $currentPos = $selectedIndex + 1
            $lblItem = $this.UIRenderer.GetLoc("UI.Label.Item", "Item")
            $lblFiltered = $this.UIRenderer.GetLoc("UI.Label.Filtered", "Filtered")
            $lblOf = $this.UIRenderer.GetLoc("UI.Label.Of", "of")
            
            $this.Console.WriteColored("  $lblItem`: ", [Constants]::ColorLabel)
            $this.Console.WriteColored("$currentPos/$filteredCount", [Constants]::ColorValue)
            $this.Console.WriteColored(" | $lblFiltered`: ", [Constants]::ColorLabel)
            $this.Console.WriteColored("$filteredCount $lblOf $totalCount", [Constants]::ColorHint)
        } else {
             $noItems = $this.UIRenderer.GetLoc("Search.NoItems", "No items found")
             $this.Console.WriteColored("  $noItems", [Constants]::ColorWarning)
        }
        
        # 3. Message / Hints
        if (-not $fastUpdate) {
            $this.Console.SetCursorPosition(0, $footerStartLine + 2)
            if (-not [string]::IsNullOrEmpty($statusMessage)) {
                 $this.Console.WriteColored("  $statusMessage", $statusColor)
            } else {
                 $hint = $this.UIRenderer.GetLoc("Search.Hint.FilteredList", "$([char]0x2191)$([char]0x2193)=Navigate | Enter=Select | Esc=Cancel")
                 $this.Console.WriteColored("  $hint", [Constants]::ColorHint)
            }
            
            # 4. Final Separator
            $this.Console.SetCursorPosition(0, $footerStartLine + 3)
            $this.Console.WriteColored($sep, [Constants]::ColorSeparator)
        }
    }
    
    [void] RenderSingleItem([array]$items, [int]$index, [int]$viewportStart, [int]$startLine, [int]$selectedIndex, [string]$focusMode, [string]$currentItem, [string]$currentMarker) {
         $i = $index - $viewportStart
         if ($i -lt 0) { return } # Should not happen if caller checks
         
         $this.Console.SetCursorPosition(0, $startLine + $i)
         $this.Console.ClearCurrentLine()
         
         if ($index -lt $items.Count) {
             $item = $items[$index]
             $isSelected = ($index -eq $selectedIndex) -and ($focusMode -eq [Constants]::FocusList)
             
             $prefix = if ($isSelected) { ">" } else { " " }
             $color = if ($isSelected) { [Constants]::ColorSelected } else { [Constants]::ColorMenuText }
             
             $this.Console.WriteColored("  $prefix ", $color)
             $this.Console.WriteColored($item, $color)
             
             if ($null -ne $currentItem -and $item -eq $currentItem) {
                 $this.Console.WriteColored(" $currentMarker", [Constants]::ColorHint)
             }
         }
    }

    [void] UpdateListSelection([array]$items, [int]$oldIndex, [int]$newIndex, [string]$focusMode, [int]$viewportStart, [int]$pageSize, [int]$headerOptionCount, [int]$headerLines, [int]$totalCount, [string]$currentItem, [string]$currentMarker) {
        $this.Console.HideCursor()
        
        $hLines = if ($headerOptionCount -gt 0) { 1 } else { 0 }
        $startLine = $headerLines + $hLines + 1 + 1
        
        # Redraw Old Item (to unselect)
        if ($oldIndex -ge $viewportStart -and $oldIndex -lt ($viewportStart + $pageSize)) {
            $this.RenderSingleItem($items, $oldIndex, $viewportStart, $startLine, $newIndex, $focusMode, $currentItem, $currentMarker)
        }
        
        # Redraw New Item (to select)
        if ($newIndex -ge $viewportStart -and $newIndex -lt ($viewportStart + $pageSize)) {
             $this.RenderSingleItem($items, $newIndex, $viewportStart, $startLine, $newIndex, $focusMode, $currentItem, $currentMarker)
        }
        
        # Update Footer (Counts Only) - Fast Update
        $footerStart = $startLine + $pageSize
        $this.RenderFooter($newIndex, $items.Count, $totalCount, $null, [ConsoleColor]::Gray, $footerStart, $false, $true)
    }

    [void] RenderList([array]$items, [int]$selectedIndex, [string]$focusMode, [int]$viewportStart, [int]$pageSize, [int]$headerOptionCount, [int]$headerLines, [int]$totalCount, [string]$currentItem, [string]$currentMarker, [string]$statusMessage, [ConsoleColor]$statusColor) {
        # Hide cursor to prevent flickering during list update
        $this.Console.HideCursor()
        
        $hLines = if ($headerOptionCount -gt 0) { 1 } else { 0 }
        
        # Consistent Layout Calc:
        # Header($headerLines) + Opts(hLines) + Input(1) + Sep(1) = StartLine
        $startLine = $headerLines + $hLines + 1 + 1
        
        # Draw items
        for ($i = 0; $i -lt $pageSize; $i++) {
            $itemIndex = $viewportStart + $i
            $this.RenderSingleItem($items, $itemIndex, $viewportStart, $startLine, $selectedIndex, $focusMode, $currentItem, $currentMarker)
        }
        
        # Explicitly redraw footer every time the list updates to ensure it's not overwritten/ghosted
        $footerStart = $startLine + $pageSize
        # Full footer render
        $this.RenderFooter($selectedIndex, $items.Count, $totalCount, $statusMessage, $statusColor, $footerStart, $false, $false)
    }

    [void] RenderFull([string]$title, [string]$searchText, [array]$items, [int]$selectedIndex, [int]$headerIndex, [string]$focusMode, [int]$viewportStart, [int]$pageSize, [int]$headerLines, [int]$totalCount, [string]$prompt, [string[]]$headerOptions, [bool]$clearScreen, [string]$currentItem, [string]$currentMarker, [string]$statusMessage, [ConsoleColor]$statusColor) {
        $this.Console.HideCursor()
        
        if ($clearScreen) {
            $this.Console.ClearScreen()
        } else {
            $this.Console.SetCursorPosition(0, 0)
        }
        
        if ($headerLines -gt 0) {
            $this.UIRenderer.RenderHeader($title)
        }
        
        if ($headerOptions.Count -gt 0) {
            if (-not $clearScreen) { $this.Console.ClearCurrentLine() }
            $this.Console.WriteColored("  ", [Constants]::ColorMenuText)
            for ($i = 0; $i -lt $headerOptions.Count; $i++) {
                 $isHeaderSelected = ($focusMode -eq [Constants]::FocusHeader -and $i -eq $headerIndex)
                 $opt = $headerOptions[$i]
                 $currentOpt = if ($isHeaderSelected) { " > $opt " } else { "   $opt " }
                 $hColor = if ($isHeaderSelected) { [Constants]::ColorSelected } else { [Constants]::ColorMenuText }
                 $this.Console.WriteColored($currentOpt, $hColor)
                 $this.Console.WriteColored("  ", [Constants]::ColorMenuText)
            }
            $this.Console.NewLine()
        }
        
        # Input
        if (-not $clearScreen) { $this.Console.ClearCurrentLine() }
        $focusIndicator = if ($focusMode -eq [Constants]::FocusInput) { ">" } else { " " }
        $inputColor = if ($focusMode -eq [Constants]::FocusInput) { [Constants]::ColorSelected } else { [Constants]::ColorMenuText }
        $this.Console.WriteColored("  $focusIndicator ", $inputColor)
        $this.Console.WriteColored("$prompt`: ", [Constants]::ColorLabel)
        
        if ([string]::IsNullOrEmpty($searchText)) {
            $placeholder = $this.UIRenderer.GetLoc("Search.TypeToFilter", "Type to filter...")
            $this.Console.WriteLineColored($placeholder, [Constants]::ColorHint)
        } else {
            $this.Console.WriteLineColored($searchText, [Constants]::ColorValue)
        }
        
        # Separator (Before List)
        if (-not $clearScreen) { $this.Console.ClearCurrentLine() }
        $this.Console.WriteSeparator("-", [Constants]::UIWidth, [Constants]::ColorSeparator)
        
        # Render List and Footer
        $this.RenderList($items, $selectedIndex, $focusMode, $viewportStart, $pageSize, $headerOptions.Count, $headerLines, $totalCount, $currentItem, $currentMarker, $statusMessage, $statusColor)
    }
    
    <#
    .SYNOPSIS
        Updates only the header options line (for header navigation)
    #>
    [void] UpdateHeaderOptions([string[]]$headerOptions, [int]$headerIndex, [string]$focusMode, [int]$headerLines) {
        if ($headerOptions.Count -eq 0) { return }
        
        # Hide cursor to prevent flickering
        $this.Console.HideCursor()
        
        $headerLine = $headerLines
        $this.Console.SetCursorPosition(0, $headerLine)
        $this.Console.ClearCurrentLine()
        
        $this.Console.WriteColored("  ", [Constants]::ColorMenuText)
        for ($i = 0; $i -lt $headerOptions.Count; $i++) {
            $isHeaderSelected = ($focusMode -eq [Constants]::FocusHeader -and $i -eq $headerIndex)
            $opt = $headerOptions[$i]
            $currentOpt = if ($isHeaderSelected) { " > $opt " } else { "   $opt " }
            $hColor = if ($isHeaderSelected) { [Constants]::ColorSelected } else { [Constants]::ColorMenuText }
            $this.Console.WriteColored($currentOpt, $hColor)
            $this.Console.WriteColored("  ", [Constants]::ColorMenuText)
        }
    }
    
    <#
    .SYNOPSIS
        Updates only the search input line (for focus changes)
    #>
    [void] UpdateSearchInput([string]$searchText, [string]$focusMode, [int]$headerLines, [int]$headerOptionCount, [string]$prompt) {
        # Hide cursor to prevent flickering
        $this.Console.HideCursor()
        
        $hLines = if ($headerOptionCount -gt 0) { 1 } else { 0 }
        $inputLine = $headerLines + $hLines
        
        $this.Console.SetCursorPosition(0, $inputLine)
        $this.Console.ClearCurrentLine()
        
        $focusIndicator = if ($focusMode -eq [Constants]::FocusInput) { ">" } else { " " }
        $inputColor = if ($focusMode -eq [Constants]::FocusInput) { [Constants]::ColorSelected } else { [Constants]::ColorMenuText }
        $this.Console.WriteColored("  $focusIndicator ", $inputColor)
        $this.Console.WriteColored("$prompt`: ", [Constants]::ColorLabel)
        
        if ([string]::IsNullOrEmpty($searchText)) {
            $placeholder = $this.UIRenderer.GetLoc("Search.TypeToFilter", "Type to filter...")
            $this.Console.WriteColored($placeholder, [Constants]::ColorHint)
        } else {
            $this.Console.WriteColored($searchText, [Constants]::ColorValue)
        }
    }
}

