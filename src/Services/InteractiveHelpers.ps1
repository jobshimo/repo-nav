<#
.SYNOPSIS
    Interactive helper functions for user operations
    
.DESCRIPTION
    These functions handle interactive user workflows that require input,
    confirmations, and step-by-step UI interactions.
    They are outside classes because they need to interact with the console directly.
#>

function Invoke-AliasEdit {
    <#
    .SYNOPSIS
        Interactive workflow to set or edit an alias
    #>
    param(
        [Parameter(Mandatory = $true)]
        $RepoManager,
        
        [Parameter(Mandatory = $true)]
        $Repository,
        
        [Parameter(Mandatory = $true)]
        $ColorSelector,
        
        [Parameter(Mandatory = $false)]
        $Console = $null,
        
        [Parameter(Mandatory = $false)]
        $Renderer = $null,

        [Parameter(Mandatory = $false)]
        $LocalizationService = $null,

        [Parameter(Mandatory = $false)]
        $OptionSelector = $null
    )
    
    # Helper for localization
    function Get-Loc([string]$key, [string]$default) {
        if ($LocalizationService) { return $LocalizationService.Get($key) }
        return $default
    }

    # If Console not provided, create a temporary one
    if ($null -eq $Console) {
        $Console = [ConsoleHelper]::new()
    }
    
    # If Renderer not provided, create a temporary one
    if ($null -eq $Renderer) {
        $prefsService = [UserPreferencesService]::new([ConfigurationService]::new())
        $Renderer = [UIRenderer]::new($Console, $prefsService)
        # If possible injection missing handled gracefully
    }
    
    $Console.ClearForWorkflow()
    $Renderer.RenderWorkflowHeader($(Get-Loc "Alias.Title" "SET ALIAS"), $Repository)
    
    $currentAlias = ""
    $currentColor = [ColorPalette]::DefaultAliasColor
    
    $lblCurrent = Get-Loc "Alias.Current" "Current alias"
    $lblPrompt = Get-Loc "Alias.Prompt" "Enter new alias (empty to remove)"

    # Check if repo already has an alias (LOGIC MODIFIED: Allow removal if empty)
    # Original logic forced "Enter to keep current".
    # New logic: Enter to remove if empty input? 
    # Wait, the user prompt says "empty to remove" in my English JSON but the code says "or press Enter to keep current".
    # I should align the code behavior or the message.
    # The original code: "If empty and there's a current alias, keep it".
    # If I want to support removal, I should check input. 
    # Let's keep original behavior for Edit (Enter keeps current) but improve UI.
    
    if ($Repository.HasAlias -and $Repository.AliasInfo) {
        $currentAlias = $Repository.AliasInfo.Alias
        # Always validate and get a safe color value
        $currentColor = [ColorPalette]::GetColorOrDefault($Repository.AliasInfo.Color)
        
        Write-Host "${lblCurrent}: " -NoNewline -ForegroundColor ([Constants]::ColorLabel)
        Write-Host $currentAlias -ForegroundColor $currentColor
        Write-Host ""
        Write-Host "New alias (Enter = keep '$currentAlias'): " -NoNewline -ForegroundColor ([Constants]::ColorLabel)
    } else {
        Write-Host "Enter alias (no spaces): " -NoNewline -ForegroundColor ([Constants]::ColorLabel)
    }
    
    $alias = Read-Host
    
    # If empty and there's a current alias, keep it
    if ([string]::IsNullOrWhiteSpace($alias) -and $currentAlias) {
        $alias = $currentAlias
    }
    
    # Validate alias
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
    
    # Select color
    $selectedColor = $currentColor
    
    if ($currentAlias -and $alias -eq $currentAlias) {
        # Ask if want to change color
        $Console.ClearForWorkflow()
        
        # Use simple confirmation here as keeping color flows better inline
        # But for standardization, let's use the new selector if available
        $keepColor = $true
        
        if ($OptionSelector) {
            Write-Host "Keep current color " -NoNewline -ForegroundColor ([Constants]::ColorLabel)
            Write-Host $currentColor -NoNewline -ForegroundColor $currentColor
            Write-Host "?" -ForegroundColor ([Constants]::ColorLabel)
            Start-Sleep -Seconds 1
             
            $title = Get-Loc "Alias.KeepColorTitle" "Keep current color?"
            $keepColor = Confirm-Selection $title $OptionSelector $LocalizationService $true
        } else {
            # Fallback
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
    
    # Create alias info and save
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

function Invoke-AliasRemove {
    <#
    .SYNOPSIS
        Interactive workflow to remove an alias
    #>
    param(
        [Parameter(Mandatory = $true)]
        $RepoManager,
        
        [Parameter(Mandatory = $true)]
        $Repository,
        
        [Parameter(Mandatory = $false)]
        $Console = $null,
        
        [Parameter(Mandatory = $false)]
        $Renderer = $null,

        [Parameter(Mandatory = $false)]
        $LocalizationService = $null,

        [Parameter(Mandatory = $false)]
        $OptionSelector = $null
    )
    
    # Helper for localization
    function Get-Loc([string]$key, [string]$default) {
        if ($LocalizationService) { return $LocalizationService.Get($key) }
        return $default
    }

    # If Console not provided, create a temporary one
    if ($null -eq $Console) {
        $Console = [ConsoleHelper]::new()
    }
    
    # If Renderer not provided, create a temporary one
    if ($null -eq $Renderer) {
        $prefsService = [UserPreferencesService]::new([ConfigurationService]::new())
        $Renderer = [UIRenderer]::new($Console, $prefsService)
    }
    
    if (-not $Repository.HasAlias) {
        $Console.ClearForWorkflow()
        Write-Host $(Get-Loc "Alias.NoAliasToRemove" "No alias to remove for this repository.") -ForegroundColor ([Constants]::ColorWarning)
        Start-Sleep -Seconds 1
        return $false
    }
    
    $Console.ClearForWorkflow()
    $Renderer.RenderWorkflowHeaderWithInfo($(Get-Loc "Alias.RemoveTitle" "REMOVE ALIAS"), $Repository, "Alias", $Repository.AliasInfo.Alias, $Repository.AliasInfo.Color)
    Write-Host $(Get-Loc "Alias.RemoveConfirm" "This will remove the alias for this repository.") -ForegroundColor ([Constants]::ColorWarning)

    $continue = if ($OptionSelector) {
        $title = Get-Loc "Prompt.Continue" "Continue?"
        Confirm-Selection $title $OptionSelector $LocalizationService $true
    } else {
        $Console.ConfirmAction($(Get-Loc "Prompt.Continue" "Continue?"), $true)
    }
    
    if ($continue) {
        $result = $RepoManager.RemoveAlias($Repository)
        
        $Console.ClearForWorkflow()
        if ($result) {
            Write-Host $(Get-Loc "Alias.RemovedSuccess" "Alias removed successfully!") -ForegroundColor ([Constants]::ColorSuccess)
        } else {
            Write-Host $(Get-Loc "Alias.RemoveFail" "Failed to remove alias.") -ForegroundColor ([Constants]::ColorError)
        }
        Start-Sleep -Seconds 1
        
        return $result
    } else {
        Write-Host "Operation cancelled." -ForegroundColor ([Constants]::ColorWarning)
        Start-Sleep -Seconds 1
        return $false
    }
}

function Invoke-NodeModulesRemove {
    <#
    .SYNOPSIS
        Interactive workflow to remove node_modules
    #>
    param(
        [Parameter(Mandatory = $true)]
        $RepoManager,
        
        [Parameter(Mandatory = $true)]
        $Repository,
        
        [Parameter(Mandatory = $false)]
        $Console = $null,
        
        [Parameter(Mandatory = $false)]
        $Renderer = $null,

        [Parameter(Mandatory = $false)]
        $LocalizationService = $null,

        [Parameter(Mandatory = $false)]
        $OptionSelector = $null
    )
    
    # Helper for localization
    function Get-Loc([string]$key, [string]$default) {
        if ($LocalizationService) { return $LocalizationService.Get($key) }
        return $default
    }

    # If Console not provided, create a temporary one
    if ($null -eq $Console) {
        $Console = [ConsoleHelper]::new()
    }
    
    # If Renderer not provided, create a temporary one
    if ($null -eq $Renderer) {
        $prefsService = [UserPreferencesService]::new([ConfigurationService]::new())
        $Renderer = [UIRenderer]::new($Console, $prefsService)
        # Handle graceful missing DI if needed
    }
    
    $nodeModulesPath = Join-Path $Repository.FullPath "node_modules"
    
    if (-not (Test-Path $nodeModulesPath)) {
        $Console.ClearForWorkflow()
        $msg = Get-Loc "Error.Repo.NoNodeModules" "No node_modules folder found in {0}"
        Write-Host ($msg -f $Repository.Name) -ForegroundColor ([Constants]::ColorWarning)
        Start-Sleep -Seconds 2
        return $false
    }
    
    $Console.ClearForWorkflow()
    $Renderer.RenderWorkflowHeader($(Get-Loc "Msg.Npm.Removing" "REMOVE NODE_MODULES"), $Repository)
    Write-Host $(Get-Loc "Msg.Npm.DeleteWarning" "This will delete the node_modules folder.") -ForegroundColor ([Constants]::ColorWarning)

    $continue = if ($OptionSelector) {
        $title = Get-Loc "Prompt.Continue" "Continue?"
        Confirm-Selection $title $OptionSelector $LocalizationService $true
    } else {
        $Console.ConfirmAction($(Get-Loc "Prompt.Continue" "Continue?"), $true)
    }

    if ($continue) {
        # Ask about package-lock.json
        $packageLockPath = Join-Path $Repository.FullPath "package-lock.json"
        $removePackageLock = $false
        
        if (Test-Path $packageLockPath) {
            Write-Host ""
            if ($OptionSelector) {
                $title = Get-Loc "Msg.Npm.RemoveLockPrompt" "Do you also want to remove package-lock.json?"
                $removePackageLock = Confirm-Selection $title $OptionSelector $LocalizationService $false
            } else {
                $removePackageLock = $Console.ConfirmAction($(Get-Loc "Msg.Npm.RemoveLockPrompt" "Do you also want to remove package-lock.json?"), $false)
            }
        }
        
        Write-Host ""
        
        $result = $RepoManager.RemoveNodeModules($Repository, $removePackageLock)
        
        Write-Host ""
        if ($result) {
            Write-Host $(Get-Loc "Msg.Npm.RemovedSuccess" "node_modules removed successfully!") -ForegroundColor ([Constants]::ColorSuccess)
             # Also mention lock file if removed
             if ($removePackageLock) {
                Write-Host $(Get-Loc "Msg.Npm.RemovedLockSuccess" "package-lock.json removed successfully!") -ForegroundColor ([Constants]::ColorSuccess)
             }
        } else {
            Write-Host $(Get-Loc "Error.Npm.RemoveFailed" "Error removing node_modules.") -ForegroundColor ([Constants]::ColorError)
        }
        Start-Sleep -Seconds 2
        return $result
    } else {
        Write-Host $(Get-Loc "Msg.ActionCancelled" "Operation cancelled.") -ForegroundColor ([Constants]::ColorWarning)
        Start-Sleep -Seconds 1
        return $false
    }
}

function Confirm-Selection {
    <#
    .SYNOPSIS
        Helper to show a Yes/No selection menu
    #>
    param(
        [string]$Title,
        [object]$OptionSelector,
        [LocalizationService]$LocalizationService,
        [bool]$DefaultYes = $true
    )

    $yesText = if ($LocalizationService) { $LocalizationService.Get("Prompt.Yes") } else { "YES" }
    $noText = if ($LocalizationService) { $LocalizationService.Get("Prompt.No") } else { "NO" }
    
    $options = @(
        @{ DisplayText = $yesText; Value = $true },
        @{ DisplayText = $noText; Value = $false }
    )
    
    # Pre-select based on default
    $currentValue = $DefaultYes

    return $OptionSelector.ShowSelection($Title, $options, $currentValue, $noText)
}

function Invoke-RepositoryClone {
    <#
    .SYNOPSIS
        Interactive workflow to clone a repository
    #>
    param(
        [Parameter(Mandatory = $true)]
        $RepoManager,
        
        [Parameter(Mandatory = $true)]
        [string]$BasePath,
        
        [Parameter(Mandatory = $false)]
        $Console = $null,

        [Parameter(Mandatory = $false)]
        $LocalizationService = $null
    )
    
    # Helper for localization
    function Get-Loc([string]$key, [string]$default) {
        if ($LocalizationService) { return $LocalizationService.Get($key) }
        return $default
    }

    # If Console not provided, create a temporary one
    if ($null -eq $Console) {
        $Console = [ConsoleHelper]::new()
    }
    
    $Console.ClearForWorkflow()
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host ("    " + $(Get-Loc "Repo.Clone.Title" "CLONE REPOSITORY")) -ForegroundColor Cyan
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host $(Get-Loc "Repo.Clone.Prompt" "Enter the Git repository URL:") -ForegroundColor Gray
    Write-Host "(e.g., https://github.com/user/repo.git)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "URL: " -NoNewline -ForegroundColor Gray
    
    $url = Read-Host
    
    if ([string]::IsNullOrWhiteSpace($url)) {
        Write-Host ""
        Write-Host "Operation cancelled (empty URL)." -ForegroundColor Yellow
        Start-Sleep -Seconds 1
        return $false
    }
    
    Write-Host ""
    Write-Host "Cloning repository..." -ForegroundColor Yellow
    Write-Host ""
    
    $result = $RepoManager.CloneRepository($url, $BasePath)
    
    Write-Host ""
    if ($result) {
        Write-Host $(Get-Loc "Repo.Clone.Success" "Repository cloned successfully!") -ForegroundColor Green
    } else {
        Write-Host "Failed to clone repository." -ForegroundColor Red
    }
    Start-Sleep -Seconds 2
    
    return $result
}

function Invoke-RepositoryDelete {
    <#
    .SYNOPSIS
        Interactive workflow to delete a repository with safety checks
    #>
    param(
        [Parameter(Mandatory = $true)]
        $RepoManager,
        
        [Parameter(Mandatory = $true)]
        $Repository,
        
        [Parameter(Mandatory = $false)]
        $Console = $null,

        [Parameter(Mandatory = $false)]
        $LocalizationService = $null,

        [Parameter(Mandatory = $false)]
        $OptionSelector = $null
    )
    
    # Helper for localization
    function Get-Loc([string]$key, [string]$default) {
        if ($LocalizationService) { return $LocalizationService.Get($key) }
        return $default
    }

    # If Console not provided, create a temporary one
    if ($null -eq $Console) {
        $Console = [ConsoleHelper]::new()
    }
    
    $Console.ClearForWorkflow()
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host ("    " + $(Get-Loc "Repo.Delete.Title" "DELETE REPOSITORY")) -ForegroundColor Red
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host "Repository: " -NoNewline -ForegroundColor Red
    Write-Host $Repository.Name -ForegroundColor White
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host ("WARNING: " + $(Get-Loc "Repo.Delete.Warning" "This action is PERMANENT and cannot be undone!")) -ForegroundColor Red
    Write-Host ""
    
    # First confirmation
    $msgConfirm = Get-Loc "Repo.Delete.Confirm" "Are you sure you want to delete {0}?"
    $confirmTitle = $msgConfirm -f $Repository.Name
    
    $firstConfirm = $false
    
    if ($OptionSelector) {
        $firstConfirm = Confirm-Selection $confirmTitle $OptionSelector $LocalizationService $false
    } else {
        # Fallback to old behavior
        Write-Host "$confirmTitle (yes/no): " -NoNewline -ForegroundColor Yellow
        $resp = Read-Host
        $firstConfirm = ($resp -eq 'yes')
    }
    
    if (-not $firstConfirm) {
        Write-Host ""
        Write-Host $(Get-Loc "Msg.ActionCancelled" "Operation cancelled.") -ForegroundColor Yellow
        Start-Sleep -Seconds 1
        return $false
    }
    
    # Load git status if not loaded
    if (-not $Repository.HasGitStatusLoaded()) {
        Write-Host ""
        Write-Host "Checking git status..." -ForegroundColor Yellow
        $RepoManager.LoadGitStatus($Repository)
    }
    
    # Check git status
    if ($Repository.GitStatus -and $Repository.GitStatus.IsGitRepo) {
        Write-Host ""
        Write-Host "Git repository detected:" -ForegroundColor Cyan
        Write-Host "  Current branch: " -NoNewline -ForegroundColor Gray
        Write-Host $Repository.GitStatus.CurrentBranch -ForegroundColor White
        
        if ($Repository.GitStatus.HasUncommittedChanges) {
            Write-Host "  Status: " -NoNewline -ForegroundColor Gray
            Write-Host "HAS UNCOMMITTED CHANGES" -ForegroundColor Red
            Write-Host ""
            Write-Host "Warning: This repository has uncommitted changes!" -ForegroundColor Red
        }
        
        if ($Repository.GitStatus.CommitsBehind -gt 0 -or $Repository.GitStatus.CommitsAhead -gt 0) {
            Write-Host "  Behind: " -NoNewline -ForegroundColor Gray
            Write-Host $Repository.GitStatus.CommitsBehind -ForegroundColor Yellow
            Write-Host "  Ahead: " -NoNewline -ForegroundColor Gray
            Write-Host $Repository.GitStatus.CommitsAhead -ForegroundColor Yellow
        }
        
        Write-Host ""
        
        # Determine the delete confirmation keyword based on language
        $deleteKeyword = Get-Loc "Prompt.DeleteConfirmInput" "DELETE"
        
        Write-Host "Type '$deleteKeyword' to confirm deletion: " -NoNewline -ForegroundColor Red
        $finalConfirm = Read-Host
        
        if ($finalConfirm -ne $deleteKeyword) {
            Write-Host ""
            Write-Host $(Get-Loc "Msg.ActionCancelled" "Operation cancelled.") -ForegroundColor Yellow
            Start-Sleep -Seconds 1
            return $false
        }
    }
    
    # Final check if not git repo (simple generic second confirmation removed as per plan, rely on first explicit one or just proceed)
    # Wait, the original code only did the second check if it WAS a git repo.
    # If it's NOT a git repo, the first YES was enough.
    # Let's keep that logic.
    
    Write-Host ""
    Write-Host "Deleting repository..." -ForegroundColor Yellow
    
    $result = $RepoManager.DeleteRepository($Repository, $true)
    
    Write-Host ""
    if ($result) {
        Write-Host "Repository deleted successfully!" -ForegroundColor Green
    } else {
        Write-Host "Failed to delete repository." -ForegroundColor Red
    }
    Start-Sleep -Seconds 2
    
    return $result
}
