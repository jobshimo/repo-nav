# IMPORTANT: INavigationCommand.ps1 must be loaded BEFORE this file

class AliasCommand : INavigationCommand {
    [string] GetDescription() {
        return "Edit (E) or Remove (R) alias"
    }

    [bool] CanExecute([object]$keyPress, [hashtable]$context) {
        $key = $keyPress.VirtualKeyCode
        return $key -eq [Constants]::KEY_E -or $key -eq [Constants]::KEY_R
    }

    [void] Execute([object]$keyPress, [hashtable]$context) {
        $state = $context.State
        $repos = $state.GetRepositories()
        $currentIndex = $state.GetCurrentIndex()
        
        if ($repos.Count -eq 0) { return }
        
        $currentRepo = $repos[$currentIndex]
        $key = $keyPress.VirtualKeyCode
        
        # Stop the navigation loop to allow interactive input
        $state.Stop()
        
        try {
            if ($key -eq [Constants]::KEY_E) {
                # Edit alias
                $this.InvokeAliasEdit($context, $currentRepo)
            }
            elseif ($key -eq [Constants]::KEY_R) {
                # Remove alias
                $this.InvokeAliasRemove($context, $currentRepo)
            }
            
            # Reload repositories to reflect alias changes
            $repoManager = $context.RepoManager
            if ($null -ne $repoManager) {
                $repoManager.LoadRepositories($context.BasePath)
                $updatedRepos = $repoManager.GetRepositories()
                $state.SetRepositories($updatedRepos)
                
                # Try to maintain selection on the same repository
                $newIndex = 0
                for ($i = 0; $i -lt $updatedRepos.Count; $i++) {
                    if ($updatedRepos[$i].Path -eq $currentRepo.Path) {
                        $newIndex = $i
                        break
                    }
                }
                $state.SetCurrentIndex($newIndex)
            }
            
            # Mark for full redraw
            $state.MarkForFullRedraw()
        }
        finally {
            # Resume navigation loop
            $state.Resume()
        }
    }

    hidden [bool] InvokeAliasEdit([hashtable]$context, [RepositoryModel]$Repository) {
        $RepoManager = $context.RepoManager
        $ColorSelector = $context.ColorSelector
        $Console = $context.Console
        $Renderer = $context.Renderer
        $LocalizationService = $context.LocalizationService
        $OptionSelector = $context.OptionSelector

        # Helper for localization
        $GetLoc = { param($key, $def) if ($LocalizationService) { return $LocalizationService.Get($key) } return $def }

        $Console.ClearForWorkflow()
        $Renderer.RenderWorkflowHeader($(& $GetLoc "Alias.Title" "SET ALIAS"), $Repository)
        
        $currentAlias = ""
        $currentColor = [ColorPalette]::DefaultAliasColor
        
        $lblCurrent = & $GetLoc "Alias.Current" "Current alias"
        
        if ($Repository.HasAlias -and $Repository.AliasInfo) {
            $currentAlias = $Repository.AliasInfo.Alias
            $currentColor = [ColorPalette]::GetColorOrDefault($Repository.AliasInfo.Color)
            
            Write-Host "${lblCurrent}: " -NoNewline -ForegroundColor ([Constants]::ColorLabel)
            Write-Host $currentAlias -ForegroundColor $currentColor
            Write-Host ""
            Write-Host "New alias (Enter = keep '$currentAlias'): " -NoNewline -ForegroundColor ([Constants]::ColorLabel)
        } else {
            Write-Host "Enter alias (no spaces): " -NoNewline -ForegroundColor ([Constants]::ColorLabel)
        }
        
        $alias = Read-Host
        
        if ([string]::IsNullOrWhiteSpace($alias) -and $currentAlias) {
            $alias = $currentAlias
        }
        
        if ([string]::IsNullOrWhiteSpace($alias) -or $alias -match '\s') {
            Write-Host ""
            if ($alias -match '\s') {
                Write-Host "Error: Alias cannot contain spaces." -ForegroundColor ([Constants]::ColorError)
            } else {
                Write-Host "Alias not saved (empty)." -ForegroundColor ([Constants]::ColorWarning)
            }
            Start-Sleep -Seconds 2
            return $false
        }
        
        $selectedColor = $currentColor
        
        if ($currentAlias -and $alias -eq $currentAlias) {
            $keepColor = $true
            
            if ($OptionSelector) {
                 $colorName = & $GetLoc "Color.$currentColor" $currentColor
                 $lblCurrentColor = & $GetLoc "Alias.CurrentColor" "Current color"
                 $desc = "$lblCurrentColor : $colorName"
                 
                 $title = & $GetLoc "Alias.KeepColorTitle" "Keep current color?"
                 $keepColor = $this.ConfirmSelection($title, $OptionSelector, $LocalizationService, $true, $desc)
            } else {
                $Console.ClearForWorkflow()
                Write-Host "Keep current color " -NoNewline -ForegroundColor ([Constants]::ColorLabel)
                Write-Host $currentColor -NoNewline -ForegroundColor $currentColor
                Write-Host "?" -ForegroundColor ([Constants]::ColorLabel)
                $keepColor = $Console.ConfirmAction("", $true)
            }
            
            if (-not $keepColor) {
                $selectedColor = $ColorSelector.SelectColor($currentColor)
            }
        } else {
            $selectedColor = $ColorSelector.SelectColor($currentColor)
        }
        
        $aliasInfo = [AliasInfo]::new($alias, $selectedColor)
        $result = $RepoManager.SetAlias($Repository, $aliasInfo)
        
        $Console.ClearForWorkflow()
        if ($result) {
            Write-Host "Alias saved successfully with color " -NoNewline -ForegroundColor ([Constants]::ColorSuccess)
            Write-Host $selectedColor -ForegroundColor $selectedColor
        } else {
            Write-Host "Failed to save alias." -ForegroundColor ([Constants]::ColorError)
        }
        Start-Sleep -Seconds 1
        return $result
    }

    hidden [bool] InvokeAliasRemove([hashtable]$context, [RepositoryModel]$Repository) {
        $RepoManager = $context.RepoManager
        $Console = $context.Console
        $Renderer = $context.Renderer
        $LocalizationService = $context.LocalizationService
        $OptionSelector = $context.OptionSelector

        # Helper for localization
        $GetLoc = { param($key, $def) if ($LocalizationService) { return $LocalizationService.Get($key) } return $def }
        
        if (-not $Repository.HasAlias) {
            $Console.ClearForWorkflow()
            Write-Host $(& $GetLoc "Alias.NoAliasToRemove" "No alias to remove for this repository.") -ForegroundColor ([Constants]::ColorWarning)
            Start-Sleep -Seconds 1
            return $false
        }
        
        $Console.ClearForWorkflow()
        $Renderer.RenderWorkflowHeaderWithInfo($(& $GetLoc "Alias.RemoveTitle" "REMOVE ALIAS"), $Repository, "Alias", $Repository.AliasInfo.Alias, $Repository.AliasInfo.Color)

        $continue = if ($OptionSelector) {
            $title = & $GetLoc "Prompt.Continue" "Continue?"
            $desc = & $GetLoc "Alias.RemoveConfirm" "This will remove the alias for this repository."
            $this.ConfirmSelection($title, $OptionSelector, $LocalizationService, $true, $desc)
        } else {
            Write-Host $(& $GetLoc "Alias.RemoveConfirm" "This will remove the alias for this repository.") -ForegroundColor ([Constants]::ColorWarning)
            $Console.ConfirmAction($(& $GetLoc "Prompt.Continue" "Continue?"), $true)
        }
        
        if ($continue) {
            $result = $RepoManager.RemoveAlias($Repository)
            
            $Console.ClearForWorkflow()
            if ($result) {
                Write-Host $(& $GetLoc "Alias.RemovedSuccess" "Alias removed successfully!") -ForegroundColor ([Constants]::ColorSuccess)
            } else {
                Write-Host $(& $GetLoc "Alias.RemoveFail" "Failed to remove alias.") -ForegroundColor ([Constants]::ColorError)
            }
            Start-Sleep -Seconds 1
            return $result
        } else {
            Write-Host "Operation cancelled." -ForegroundColor ([Constants]::ColorWarning)
            Start-Sleep -Seconds 1
            return $false
        }
    }

    hidden [bool] ConfirmSelection($title, $OptionSelector, $LocalizationService, $defaultYes, $description) {
        $yesText = if ($LocalizationService) { $LocalizationService.Get("Prompt.Yes") } else { "Yes" }
        $noText = if ($LocalizationService) { $LocalizationService.Get("Prompt.No") } else { "No" }
        
        $options = @(
            @{ DisplayText = $yesText; Value = $true },
            @{ DisplayText = $noText; Value = $false }
        )
        
        $result = $OptionSelector.ShowSelection($title, $options, $defaultYes, "Cancel", $false, $description)
        
        if ($null -eq $result) { return $false }
        return $result
    }
}


