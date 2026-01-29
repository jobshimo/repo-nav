class ConsoleView {
    [ConsoleHelper] $Console

    ConsoleView([ConsoleHelper]$console) {
        $this.Console = $console
    }

    [int] CalculatePageSize([int]$totalOptions, [int]$listStartTop, [int]$reservedFooterLines) {
        $windowHeight = $this.Console.GetWindowHeight()
        $availableHeight = $windowHeight - $listStartTop - $reservedFooterLines
        
        if ($availableHeight -lt 1) { 
            return 1 
        }
        
        return [Math]::Min($totalOptions, $availableHeight)
    }

    [int] CalculateViewportStart([int]$selectedIndex, [int]$currentViewportStart, [int]$pageSize, [int]$totalOptions) {
        $viewportStart = $currentViewportStart

        if ($selectedIndex -lt $viewportStart) {
            $viewportStart = $selectedIndex
        }
        elseif ($selectedIndex -ge ($viewportStart + $pageSize)) {
            $viewportStart = $selectedIndex - $pageSize + 1
        }
        
        # Ensure bounds
        if ($viewportStart -lt 0) { $viewportStart = 0 }
        if ($viewportStart + $pageSize -gt $totalOptions) { $viewportStart = $totalOptions - $pageSize }

        return $viewportStart
    }

    [void] ClearLine() {
        $this.Console.ClearCurrentLine()
    }

    [void] WriteColored([string]$text, [System.ConsoleColor]$color) {
        $this.Console.WriteColored($text, $color)
    }

    [void] WriteLineColored([string]$text, [System.ConsoleColor]$color) {
        $this.Console.WriteLineColored($text, $color)
    }

    [void] NewLine() {
        $this.Console.NewLine()
    }
}
