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
        $Console = $null
    )
    
    # If Console not provided, create a temporary one
    if ($null -eq $Console) {
        $Console = [ConsoleHelper]::new()
    }
    
    $Console.ClearForWorkflow()
    Write-Host "=======================================================" -ForegroundColor ([Constants]::ColorSeparator)
    Write-Host "    SET ALIAS" -ForegroundColor ([Constants]::ColorHeader)
    Write-Host "=======================================================" -ForegroundColor ([Constants]::ColorSeparator)
    Write-Host "Repository: " -NoNewline -ForegroundColor ([Constants]::ColorPrompt)
    Write-Host $Repository.Name -ForegroundColor ([Constants]::ColorValue)
    Write-Host "=======================================================" -ForegroundColor ([Constants]::ColorSeparator)
    Write-Host ""
    
    $currentAlias = ""
    $currentColor = [ColorPalette]::DefaultAliasColor
    
    # Check if repo already has an alias
    if ($Repository.HasAlias -and $Repository.AliasInfo) {
        $currentAlias = $Repository.AliasInfo.Alias
        # Always validate and get a safe color value
        $currentColor = [ColorPalette]::GetColorOrDefault($Repository.AliasInfo.Color)
        
        Write-Host "Current alias: " -NoNewline -ForegroundColor ([Constants]::ColorLabel)
        Write-Host $currentAlias -ForegroundColor $currentColor
        Write-Host ""
        Write-Host "[current: $currentAlias]" -ForegroundColor ([Constants]::ColorHint)
        Write-Host "New alias (or press Enter to keep current): " -NoNewline -ForegroundColor ([Constants]::ColorLabel)
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
        Write-Host "Keep current color " -NoNewline -ForegroundColor ([Constants]::ColorLabel)
        Write-Host $currentColor -NoNewline -ForegroundColor $currentColor
        Write-Host "?" -ForegroundColor ([Constants]::ColorLabel)
        $keepColor = $Console.ConfirmAction("", $true)
        
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
        $Console = $null
    )
    
    # If Console not provided, create a temporary one
    if ($null -eq $Console) {
        $Console = [ConsoleHelper]::new()
    }
    
    if (-not $Repository.HasAlias) {
        $Console.ClearForWorkflow()
        Write-Host "No alias to remove for this repository." -ForegroundColor ([Constants]::ColorWarning)
        Start-Sleep -Seconds 1
        return $false
    }
    
    $Console.ClearForWorkflow()
    Write-Host "=======================================================" -ForegroundColor ([Constants]::ColorSeparator)
    Write-Host "    REMOVE ALIAS" -ForegroundColor ([Constants]::ColorHeader)
    Write-Host "=======================================================" -ForegroundColor ([Constants]::ColorSeparator)
    Write-Host "Repository: " -NoNewline -ForegroundColor ([Constants]::ColorPrompt)
    Write-Host $Repository.Name -ForegroundColor ([Constants]::ColorValue)
    Write-Host "Alias: " -NoNewline -ForegroundColor ([Constants]::ColorPrompt)
    Write-Host "$($Repository.AliasInfo.Alias)" -ForegroundColor $Repository.AliasInfo.Color
    Write-Host "=======================================================" -ForegroundColor ([Constants]::ColorSeparator)
    Write-Host ""
    Write-Host "This will remove the alias for this repository." -ForegroundColor ([Constants]::ColorWarning)
    
    if ($Console.ConfirmAction("Continue?", $true)) {
        $result = $RepoManager.RemoveAlias($Repository)
        
        $Console.ClearForWorkflow()
        if ($result) {
            Write-Host "Alias removed successfully!" -ForegroundColor ([Constants]::ColorSuccess)
        } else {
            Write-Host "Failed to remove alias." -ForegroundColor ([Constants]::ColorError)
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
        $Console = $null
    )
    
    # If Console not provided, create a temporary one
    if ($null -eq $Console) {
        $Console = [ConsoleHelper]::new()
    }
    
    $nodeModulesPath = Join-Path $Repository.FullPath "node_modules"
    
    if (-not (Test-Path $nodeModulesPath)) {
        $Console.ClearForWorkflow()
        Write-Host "No node_modules folder found in this repository." -ForegroundColor ([Constants]::ColorWarning)
        Start-Sleep -Seconds 2
        return $false
    }
    
    $Console.ClearForWorkflow()
    Write-Host "=======================================================" -ForegroundColor ([Constants]::ColorSeparator)
    Write-Host "    REMOVE NODE_MODULES" -ForegroundColor ([Constants]::ColorHeader)
    Write-Host "=======================================================" -ForegroundColor ([Constants]::ColorSeparator)
    Write-Host "Repository: " -NoNewline -ForegroundColor ([Constants]::ColorPrompt)
    Write-Host $Repository.Name -ForegroundColor ([Constants]::ColorValue)
    Write-Host "=======================================================" -ForegroundColor ([Constants]::ColorSeparator)
    Write-Host ""
    Write-Host "This will delete the node_modules folder." -ForegroundColor ([Constants]::ColorWarning)
    
    if ($Console.ConfirmAction("Continue?", $true)) {
        # Ask about package-lock.json
        $packageLockPath = Join-Path $Repository.FullPath "package-lock.json"
        $removePackageLock = $false
        
        if (Test-Path $packageLockPath) {
            Write-Host ""
            $removePackageLock = $Console.ConfirmAction("Do you also want to remove package-lock.json?", $false)
        }
        
        Write-Host ""
        
        $result = $RepoManager.RemoveNodeModules($Repository, $removePackageLock)
        
        Write-Host ""
        if ($result) {
            Write-Host "node_modules removed successfully!" -ForegroundColor ([Constants]::ColorSuccess)
        } else {
            Write-Host "Error removing node_modules." -ForegroundColor ([Constants]::ColorError)
        }
        Start-Sleep -Seconds 2
        return $result
    } else {
        Write-Host "Operation cancelled." -ForegroundColor ([Constants]::ColorWarning)
        Start-Sleep -Seconds 1
        return $false
    }
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
        $Console = $null
    )
    
    # If Console not provided, create a temporary one
    if ($null -eq $Console) {
        $Console = [ConsoleHelper]::new()
    }
    
    $Console.ClearForWorkflow()
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host "    CLONE REPOSITORY" -ForegroundColor Cyan
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Enter the Git repository URL:" -ForegroundColor Gray
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
        Write-Host "Repository cloned successfully!" -ForegroundColor Green
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
        $Console = $null
    )
    
    # If Console not provided, create a temporary one
    if ($null -eq $Console) {
        $Console = [ConsoleHelper]::new()
    }
    
    $Console.ClearForWorkflow()
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host "    DELETE REPOSITORY" -ForegroundColor Red
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host "Repository: " -NoNewline -ForegroundColor Red
    Write-Host $Repository.Name -ForegroundColor White
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "WARNING: This action is PERMANENT and cannot be undone!" -ForegroundColor Red
    Write-Host ""
    
    # First confirmation
    Write-Host "Are you sure you want to delete this repository? (yes/no): " -NoNewline -ForegroundColor Yellow
    $firstConfirm = Read-Host
    
    if ($firstConfirm -ne 'yes') {
        Write-Host ""
        Write-Host "Operation cancelled." -ForegroundColor Yellow
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
        Write-Host "Type 'DELETE' to confirm deletion: " -NoNewline -ForegroundColor Red
        $finalConfirm = Read-Host
        
        if ($finalConfirm -ne 'DELETE') {
            Write-Host ""
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            Start-Sleep -Seconds 1
            return $false
        }
    }
    
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
