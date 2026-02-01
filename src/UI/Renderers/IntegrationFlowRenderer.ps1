class IntegrationFlowRenderer : IIntegrationFlowRenderer {
    [object] $Console
    [object] $Renderer
    [object] $LocalizationService

    IntegrationFlowRenderer([object]$console, [object]$renderer, [object]$localizationService) {
        $this.Console = $console
        $this.Renderer = $renderer
        $this.LocalizationService = $localizationService
    }

    [string] GetLoc([string]$key, [string]$default) {
        if ($null -ne $this.LocalizationService) {
            return $this.LocalizationService.Get($key)
        }
        return $default
    }

    [void] RenderInteractiveDashboard([hashtable]$flowState, [int]$selectedIndex) {
        $title = $this.GetLoc("Flow.Dashboard.Title", "INTEGRATION FLOW DASHBOARD")
        $this.Renderer.RenderHeader($title)
        $this.Console.NewLine()
        
        $targetLabel = $this.GetLoc("Flow.Dashboard.Target", "TARGET (Remote)").PadRight(20)
        $nameLabel = $this.GetLoc("Flow.Dashboard.Name", "BRANCH NAME").PadRight(20)
        $sourceLabel = $this.GetLoc("Flow.Dashboard.Source", "SOURCE (Local)").PadRight(20)
        
        # Items mapping:
        # 0: Target Branch
        # 1: New Branch Name
        # 2: Source Branch
        # 3: Execute (if valid) OR Exit (if invalid)
        
        # 0. Target Item
        $this.RenderStateItem(0, $targetLabel, $flowState.TargetBranch, $flowState.TargetBranchValid, ($selectedIndex -eq 0))
        
        # 1. New Branch Item
        $this.RenderStateItem(1, $nameLabel, $flowState.NewBranchName, $flowState.NewBranchNameValid, ($selectedIndex -eq 1))
        
        # 2. Source Item
        $this.RenderStateItem(2, $sourceLabel, $flowState.SourceBranch, $flowState.SourceBranchValid, ($selectedIndex -eq 2))
        
        $this.Console.NewLine()
        
        # Calculate dynamic index for Execute/Exit
        $canExecute = $flowState.TargetBranchValid -and $flowState.NewBranchNameValid -and $flowState.SourceBranchValid
        
        $executeText = "[ " + $this.GetLoc("Flow.Dashboard.Execute", "EXECUTE INTEGRATION") + " ]"
        $exitText = "[ " + $this.GetLoc("Flow.Dashboard.Exit", "Exit / Cancel") + " ]"
        
        if ($canExecute) {
            # 3. Execute
            $isSel = ($selectedIndex -eq 3)
            $prefix = if ($isSel) { "  > " } else { "    " }
            # If valid, show reliable Execute option
            $this.Console.WriteColored($prefix, [Constants]::ColorHighlight)
            $color = if ($isSel) { [Constants]::ColorSelected } else { [Constants]::ColorSuccess }
            $this.Console.WriteLineColored($executeText, $color)
            
            # 4. Exit
            $isSelExit = ($selectedIndex -eq 4)
            $prefixExit = if ($isSelExit) { "  > " } else { "    " }
            $this.Console.WriteColored($prefixExit, [Constants]::ColorHighlight)
            $colorExit = if ($isSelExit) { [Constants]::ColorSelected } else { [Constants]::ColorHint }
            $this.Console.WriteLineColored($exitText, $colorExit)
        } else {
            # 3. Exit (since Execute is hidden/disabled)
            $isSel = ($selectedIndex -eq 3)
            $prefix = if ($isSel) { "  > " } else { "    " }
            $this.Console.WriteColored($prefix, [Constants]::ColorHighlight)
            $color = if ($isSel) { [Constants]::ColorSelected } else { [Constants]::ColorHint }
            $this.Console.WriteLineColored($exitText, $color)
        }
        
        $this.Console.NewLine()
        $hintText = $this.GetLoc("Flow.Dashboard.Hint", "Use Arrows to navigate | Enter to edit/select")
        $this.Console.WriteLineColored("  $hintText", [Constants]::ColorHint)
    }

    hidden [void] RenderStateItem([int]$index, [string]$label, [string]$value, [bool]$isValid, [bool]$isSelected) {
        $prefix = if ($isSelected) { "  > " } else { "    " }
        
        $this.Console.WriteColored($prefix, [Constants]::ColorHighlight)
        $this.Console.WriteColored("$label : ", [Constants]::ColorLabel)
        
        if ([string]::IsNullOrWhiteSpace($value)) {
            $notSel = $this.GetLoc("Flow.Dashboard.NotSelected", "<Not Selected>")
            $this.Console.WriteLineColored($notSel, [Constants]::ColorHint)
        } else {
            $color = if ($isValid) { [Constants]::ColorValue } else { [Constants]::ColorWarning }
            $this.Console.WriteLineColored($value, $color)
        }
    }

    [void] RenderExecutionStatus([string]$message, [bool]$success) {
        $color = if ($success) { [Constants]::ColorSuccess } else { [Constants]::ColorError }
        $prefix = if ($success) { "[v]" } else { "[x]" }
        $this.Console.WriteLineColored("  $prefix $message", $color)
    }
}
