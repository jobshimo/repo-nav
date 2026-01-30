class OptionSelector : ConsoleView {
    [UIRenderer] $Renderer
    OptionSelector([ConsoleHelper]$console, [object]$renderer) : base($console) {
        $this.Renderer = $renderer
    }
    [object] ShowSelection([string]$title, [array]$options, [object]$currentValue, [string]$cancelText) {
        return $this.ShowSelection($title, $options, $currentValue, $cancelText, $true, "", [Constants]::ColorWarning, $true)
    }
    [object] ShowSelection([string]$title, [array]$options, [object]$currentValue, [string]$cancelText, [bool]$showCurrentMarker, [string]$description, [ConsoleColor]$descriptionColor, [bool]$clearScreen = $true) {
        if ($options.Count -eq 0) {
            return $null
        }
        if ($descriptionColor -eq 0) { $descriptionColor = [Constants]::ColorWarning }
        $selectedIndex = 0
        for ($i = 0; $i -lt $options.Count; $i++) {
            if ($options[$i].Value -eq $currentValue) {
                $selectedIndex = $i
                break
            }
        }
        $running = $true
        $result = $null
        try {
            $this.Console.HideCursor()
            if ($clearScreen) {
                $this.Console.ClearScreen()
            }
            $this.Renderer.RenderHeader($title)
            $preferences = $this.Renderer.PreferencesService.LoadPreferences()
            $showHeaders = if ($preferences.display.PSObject.Properties.Name -contains 'showHeaders') { $preferences.display.showHeaders } else { $true }
            if (-not $showHeaders) {
                $this.WriteLineColored("  $title", [Constants]::ColorHighlight)
                $this.Console.WriteSeparator("-", [Constants]::UIWidth, [Constants]::ColorSeparator)
            }
            $this.NewLine()
            if (-not [string]::IsNullOrWhiteSpace($description)) {
                $this.WriteLineColored("  $description", $descriptionColor)
                $this.NewLine()
            }
            $listStartTop = $this.Console.GetCursorTop()
            $viewportStart = 0
            $reservedFooter = 6
            while ($running) {
                $pageSize = $this.CalculatePageSize($options.Count, $listStartTop, $reservedFooter)
                $viewportStart = $this.CalculateViewportStart($selectedIndex, $viewportStart, $pageSize, $options.Count)
                $this.Console.SetCursorPosition(0, $listStartTop)
                for ($i = 0; $i -lt $pageSize; $i++) {
                    $optionIndex = $viewportStart + $i
                    $option = $options[$optionIndex]
                    $prefix = if ($optionIndex -eq $selectedIndex) { ">" } else { " " }
                    $color = if ($optionIndex -eq $selectedIndex) { [Constants]::ColorSelected } else { [Constants]::ColorMenuText }
                    $currentMarker = if ($showCurrentMarker -and $option.Value -eq $currentValue) { " (current)" } else { "" }
                    $displayLine = "  $prefix $($option.DisplayText)$currentMarker"
                    $isColorPreview = $false
                    if ($option.Value -ne 'None' -and ($option.Value -as [System.ConsoleColor])) {
                        $isColorPreview = $true
                    }
                    $this.ClearLine()
                    if ($isColorPreview) {
                        $this.WriteLineColored($displayLine, $option.Value)
                    } else {
                        $this.WriteLineColored($displayLine, $color)
                    }
                }
                $this.NewLine()
                $this.ClearLine()
                $this.WriteLineColored("  $cancelText", [Constants]::ColorHint)
                $this.NewLine()
                $this.NewLine()
                $this.ClearLine()
                $this.WriteLineColored("  Use Arrows to navigate | Enter to select | Q/Esc to cancel", [Constants]::ColorHint)
                $key = $this.Console.ReadKey()
                switch ($key.VirtualKeyCode) {
                    ([Constants]::KEY_UP_ARROW) {
                        if ($selectedIndex -gt 0) {
                            $selectedIndex--
                        } else {
                            $selectedIndex = $options.Count - 1
                        }
                    }
                    ([Constants]::KEY_DOWN_ARROW) {
                        if ($selectedIndex -lt ($options.Count - 1)) {
                            $selectedIndex++
                        } else {
                            $selectedIndex = 0
                        }
                    }
                    ([Constants]::KEY_ENTER) {
                        $result = $options[$selectedIndex].Value
                        $running = $false
                    }
                    ([Constants]::KEY_Q) {
                        $running = $false
                    }
                    ([Constants]::KEY_ESC) {
                        $running = $false
                    }
                }
            }
        }
        finally {
            $this.Console.HideCursor()
        }
        return $result
    }
    [bool] SelectYesNo([string]$question, [object]$localizationService, [bool]$clearScreen = $true) {
        $yesText = "Yes"
        $noText = "No"
        $cancelText = "Cancel"
        if ($null -ne $localizationService) {
            $yesText = $localizationService.Get("Prompt.Yes")
            $noText = $localizationService.Get("Prompt.No")
            $cancelText = $localizationService.Get("Prompt.Cancel")
        }
        $options = @(
            @{ DisplayText = $yesText; Value = $true },
            @{ DisplayText = $noText; Value = $false }
        )
        $result = $this.ShowSelection($question, $options, $false, $cancelText, $false, "", [Constants]::ColorWarning, $clearScreen)
        if ($null -eq $result) {
            return $false
        }
        return $result
    }
    [bool] SelectYesNo([string]$question) {
        return $this.SelectYesNo($question, $null, $true)
    }
    [bool] SelectYesNo([string]$question, [bool]$clearScreen) {
        return $this.SelectYesNo($question, $null, $clearScreen)
    }
}
