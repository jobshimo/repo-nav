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
        
        # NOTE: Removed the initial 4-line clear loop which caused flickering.
        # Instead, we overwrite content or clear line-by-line just before writing if needed.
        
        # 1. Separator
        if (-not $fastUpdate) {
            $this.Console.SetCursorPosition(0, $footerStartLine)
            $this.Console.WriteColored($sep, [Constants]::ColorSeparator)
        }
        
        # 2. Counts (This changes on selection, so we redraw it)
        $this.Console.SetCursorPosition(0, $footerStartLine + 1)
        
        $lineLength = 0
        
        if ($filteredCount -gt 0) {
            # 1-based index for display
            $currentPos = $selectedIndex + 1
            $lblItem = $this.UIRenderer.GetLoc("UI.Label.Item", "Item")
            $lblFiltered = $this.UIRenderer.GetLoc("UI.Label.Filtered", "Filtered")
            $lblOf = $this.UIRenderer.GetLoc("UI.Label.Of", "of")
            
            # Build string parts to calc length
            # "  Item: "
            $part1 = "  $lblItem`: "
            $this.Console.WriteColored($part1, [Constants]::ColorLabel)
            
            # "1/10"
            $part2 = "$currentPos/$filteredCount"
            $this.Console.WriteColored($part2, [Constants]::ColorValue)
            
            # " | Filtered: "
            $part3 = " | $lblFiltered`: "
            $this.Console.WriteColored($part3, [Constants]::ColorLabel)
            
            # "10 of 100"
            $part4 = "$filteredCount $lblOf $totalCount"
            $this.Console.WriteColored($part4, [Constants]::ColorHint)
            
            $lineLength = $part1.Length + $part2.Length + $part3.Length + $part4.Length
        } else {
             $noItems = $this.UIRenderer.GetLoc("Search.NoItems", "No items found")
             $prefix = "  "
             $this.Console.WriteColored("$prefix$noItems", [Constants]::ColorWarning)
             $lineLength = $prefix.Length + $noItems.Length
        }
        
        # Clear remaining part of the line to avoid artifacts
        if ($lineLength -lt [Constants]::UIWidth) {
            $pad = " " * ([Constants]::UIWidth - $lineLength)
            $this.Console.Write($pad)
        }
        
        # 3. Message / Hints
        if (-not $fastUpdate) {
            $this.Console.SetCursorPosition(0, $footerStartLine + 2)
            $msgLength = 0
            
            if (-not [string]::IsNullOrEmpty($statusMessage)) {
                 $prefix = "  "
                 $this.Console.WriteColored("$prefix$statusMessage", $statusColor)
                 $msgLength = $prefix.Length + $statusMessage.Length
            } else {
                 $hint = $this.UIRenderer.GetLoc("Search.Hint.FilteredList", "$([char]0x2191)$([char]0x2193)=Navigate | Enter=Select | Q/Esc=Cancel")
                 $prefix = "  "
                 $this.Console.WriteColored("$prefix$hint", [Constants]::ColorHint)
                 $msgLength = $prefix.Length + $hint.Length
            }
            
            # Fill rest with spaces
            if ($msgLength -lt [Constants]::UIWidth) {
                # Ensure we don't error on negative count if message is somehow huge
                $remaining = [Math]::Max(0, [Constants]::UIWidth - $msgLength)
                $pad = " " * $remaining
                $this.Console.Write($pad)
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

