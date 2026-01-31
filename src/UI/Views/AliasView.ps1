class AliasView {
    [ConsoleHelper] $Console
    [LocalizationService] $LocalizationService
    [IUIRenderer] $Renderer
    [ColorSelector] $ColorSelector
    [OptionSelector] $OptionSelector

    AliasView(
        [ConsoleHelper]$console, 
        [LocalizationService]$localizationService, 
        [IUIRenderer]$renderer,
        [ColorSelector]$colorSelector,
        [OptionSelector]$optionSelector
    ) {
        $this.Console = $console
        $this.LocalizationService = $localizationService
        $this.Renderer = $renderer
        $this.ColorSelector = $colorSelector
        $this.OptionSelector = $optionSelector
    }

    # Helper for localization
    hidden [string] GetLoc([string]$key, [string]$default) {
        if ($this.LocalizationService) { return $this.LocalizationService.Get($key) }
        return $default
    }

    # Get alias information from user
    # Returns AliasInfo object or $null
    [AliasInfo] GetAliasDetails([RepositoryModel]$repository) {
        $this.Console.ClearForWorkflow()
        
        $title = $this.GetLoc("Alias.Title", "SET ALIAS")
        $this.Renderer.RenderWorkflowHeader($title, $repository)
        
        $currentAlias = ""
        $currentColor = [ColorPalette]::DefaultAliasColor
        
        if ($repository.HasAlias -and $repository.AliasInfo) {
            $currentAlias = $repository.AliasInfo.Alias
            $currentColor = [ColorPalette]::GetColorOrDefault($repository.AliasInfo.Color)
            
            $lblCurrent = $this.GetLoc("Alias.Current", "Current alias")
            Write-Host "${lblCurrent}: " -NoNewline -ForegroundColor ([Constants]::ColorLabel)
            Write-Host $currentAlias -ForegroundColor $currentColor
            Write-Host ""
            
            $prompt = $this.GetLoc("Alias.NewPrompt", "New alias (Enter = keep '{0}'): ") -f $currentAlias
            Write-Host $prompt -NoNewline -ForegroundColor ([Constants]::ColorLabel)
        } else {
            $prompt = $this.GetLoc("Alias.EnterPrompt", "Enter alias (no spaces): ")
            Write-Host $prompt -NoNewline -ForegroundColor ([Constants]::ColorLabel)
        }
        
        $alias = Read-Host
        
        # Handle keeping current alias
        if ([string]::IsNullOrWhiteSpace($alias) -and $currentAlias) {
            $alias = $currentAlias
        }
        
        # Validation
        if ([string]::IsNullOrWhiteSpace($alias) -or $alias -match '\s') {
            Write-Host ""
            if ($alias -match '\s') {
                $msg = $this.GetLoc("Error.AliasSpaces", "Error: Alias cannot contain spaces.")
                Write-Host $msg -ForegroundColor ([Constants]::ColorError)
            } else {
                $msg = $this.GetLoc("Error.AliasEmpty", "Alias not saved (empty).")
                Write-Host $msg -ForegroundColor ([Constants]::ColorWarning)
            }
            Start-Sleep -Seconds 2
            return $null
        }
        
        # Color Selection Logic
        $selectedColor = $currentColor
        
        # If updating existing alias (or keeping name), ask about color
        if ($currentAlias -and $alias -eq $currentAlias) {
            $keepColor = $this.AskKeepColor($currentColor)
            
            if (-not $keepColor) {
                $selectedColor = $this.ColorSelector.SelectColor($currentColor)
            }
        } else {
            # New alias or changed name -> select color
            $selectedColor = $this.ColorSelector.SelectColor($currentColor)
        }
        
        return [AliasInfo]::new($alias, $selectedColor)
    }
    
    hidden [bool] AskKeepColor([string]$currentColor) {
        if ($this.OptionSelector) {
             $colorName = $this.GetLoc("Color.$currentColor", $currentColor)
             $lblCurrentColor = $this.GetLoc("Alias.CurrentColor", "Current color")
             $desc = "$lblCurrentColor : $colorName"
             $title = $this.GetLoc("Alias.KeepColorTitle", "Keep current color?")
             
             # Reuse ConfirmSelection logic or implement it here
             return $this.ConfirmSelection($title, $desc)
        } else {
            $this.Console.ClearForWorkflow()
            Write-Host "Keep current color " -NoNewline -ForegroundColor ([Constants]::ColorLabel)
            Write-Host $currentColor -NoNewline -ForegroundColor $currentColor
            Write-Host "?" -ForegroundColor ([Constants]::ColorLabel)
            return $this.Console.ConfirmAction("", $true)
        }
    }
    
    hidden [bool] ConfirmSelection($title, $description) {
        $yesText = $this.GetLoc("Prompt.Yes", "Yes")
        $noText = $this.GetLoc("Prompt.No", "No")
        
        # Use SelectionOptions for type-safe, readable configuration
        $config = [SelectionOptions]::new()
        $config.Title = $title
        $config.Options = @(
            @{ DisplayText = $yesText; Value = $true },
            @{ DisplayText = $noText; Value = $false }
        )
        $config.CancelText = $noText
        $config.ShowCurrentMarker = $false
        $config.Description = $description
        
        $result = $this.OptionSelector.Show($config)
        
        if ($null -eq $result) { return $false } 
        return $result
    }

    # Show save result
    [void] ShowSaveResult([bool]$success, [AliasInfo]$aliasInfo) {
        $this.Console.ClearForWorkflow()
        if ($success) {
            $msg = $this.GetLoc("Alias.SavedSuccess", "Alias saved successfully with color ")
            Write-Host $msg -NoNewline -ForegroundColor ([Constants]::ColorSuccess)
            Write-Host $aliasInfo.Color -ForegroundColor $aliasInfo.Color
        } else {
            $msg = $this.GetLoc("Alias.SaveFail", "Failed to save alias.")
            Write-Host $msg -ForegroundColor ([Constants]::ColorError)
        }
        Start-Sleep -Seconds 1
    }

    # Confirm alias removal
    [bool] ConfirmRemove([RepositoryModel]$repository) {
        if (-not $repository.HasAlias) {
            $this.Console.ClearForWorkflow()
            $msg = $this.GetLoc("Alias.NoAliasToRemove", "No alias to remove for this repository.")
            Write-Host $msg -ForegroundColor ([Constants]::ColorWarning)
            Start-Sleep -Seconds 1
            return $false
        }
        
        $this.Console.ClearForWorkflow()
        $title = $this.GetLoc("Alias.RemoveTitle", "REMOVE ALIAS")
        
        $this.Renderer.RenderWorkflowHeaderWithInfo(
            $title, 
            $repository, 
            "Alias", 
            $repository.AliasInfo.Alias, 
            $repository.AliasInfo.Color
        )

        $desc = $this.GetLoc("Alias.RemoveConfirm", "This will remove the alias for this repository.")
        
        if ($this.OptionSelector) {
            $confirmTitle = $this.GetLoc("Prompt.Continue", "Continue?")
            if ($this.ConfirmSelection($confirmTitle, $desc)) {
                return $true
            }
        } else {
            Write-Host $desc -ForegroundColor ([Constants]::ColorWarning)
            if ($this.Console.ConfirmAction($this.GetLoc("Prompt.Continue", "Continue?"), $true)) {
                return $true
            }
        }
        
        $msg = $this.GetLoc("Prompt.Cancelled", "Operation cancelled.")
        Write-Host $msg -ForegroundColor ([Constants]::ColorWarning)
        Start-Sleep -Seconds 1
        return $false
    }
    
    # Show remove result
    [void] ShowRemoveResult([bool]$success) {
        $this.Console.ClearForWorkflow()
        if ($success) {
            $msg = $this.GetLoc("Alias.RemovedSuccess", "Alias removed successfully!")
            Write-Host $msg -ForegroundColor ([Constants]::ColorSuccess)
        } else {
            $msg = $this.GetLoc("Alias.RemoveFail", "Failed to remove alias.")
            Write-Host $msg -ForegroundColor ([Constants]::ColorError)
        }
        Start-Sleep -Seconds 1
    }
}
