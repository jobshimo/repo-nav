class RepositoryManagementView {
    [ConsoleHelper] $Console
    [LocalizationService] $LocalizationService
    [IUIRenderer] $Renderer
    [OptionSelector] $OptionSelector

    RepositoryManagementView([ConsoleHelper]$console, [LocalizationService]$localizationService, [IUIRenderer]$renderer, [OptionSelector]$optionSelector) {
        $this.Console = $console
        $this.LocalizationService = $localizationService
        $this.Renderer = $renderer
        $this.OptionSelector = $optionSelector
    }

    # Helper method for localization
    hidden [string] GetLoc([string]$key, [string]$default) {
        if ($this.LocalizationService) { return $this.LocalizationService.Get($key) }
        return $default
    }

    # Prompt user for cloning information
    # Returns hashtable @{ Url = "url"; Name = "name" } or $null if cancelled
    [hashtable] GetCloneDetails([string]$targetPath) {
        $this.Console.ClearForWorkflow()
        
        $header = $this.GetLoc("Repo.CloneTitle", "CLONE REPOSITORY")
        $this.Renderer.RenderWorkflowHeader($header)
        
        # Display current target path
        $pathLabel = $this.GetLoc("Repo.CloneTarget", "Cloning into:")
        Write-Host "$pathLabel " -NoNewline -ForegroundColor ([Constants]::ColorLabel)
        Write-Host $targetPath -ForegroundColor ([Constants]::ColorValue)
        Write-Host ""
        
        # Get URL
        $urlPrompt = $this.GetLoc("Repo.Clone.Prompt", "Enter repository URL")
        Write-Host "${urlPrompt}: " -NoNewline -ForegroundColor ([Constants]::ColorPrompt)
        [Console]::CursorVisible = $true
        $url = Read-Host
        
        if ([string]::IsNullOrWhiteSpace($url)) {
            $msg = $this.GetLoc("Prompt.Cancelled", "Operation cancelled.")
            Write-Host $msg -ForegroundColor ([Constants]::ColorWarning)
            Start-Sleep -Seconds 1
            return $null
        }
        
        # Extract default name
        try {
            # Handle URLs ending in slash
            $cleanUrl = $url.TrimEnd('/')
            $defaultName = $cleanUrl.Split('/')[-1].Replace('.git', '')
        } catch {
            $defaultName = "repository"
        }
        
        # Get Custom Name - Improved UI
        $namePrompt = $this.GetLoc("Repo.Clone.NamePrompt", "Folder name")
        Write-Host "$namePrompt " -NoNewline -ForegroundColor ([Constants]::ColorPrompt)
        Write-Host "[$defaultName]" -NoNewline -ForegroundColor ([Constants]::ColorHint)
        Write-Host ": " -NoNewline -ForegroundColor ([Constants]::ColorPrompt)
        
        $customName = Read-Host
        [Console]::CursorVisible = $false
        
        if ([string]::IsNullOrWhiteSpace($customName)) {
             $customName = $defaultName
             Write-Host "Using default: $defaultName" -ForegroundColor ([Constants]::ColorInfo)
             Start-Sleep -Milliseconds 500
        }
        
        return @{
            Url = $url
            Name = $customName
        }
    }

    # Show validation error for target path exists
    [void] ShowTargetExistsError([string]$repoName) {
        $msg = $this.GetLoc("Error.FolderExists", "Error: Folder '{0}' already exists.") -f $repoName
        Write-Host $msg -ForegroundColor ([Constants]::ColorError)
        Start-Sleep -Seconds 2
    }

    # Show cloning in progress message
    [void] ShowCloningMessage([string]$targetPath) {
        Write-Host ""
        $msg = $this.GetLoc("Repo.CloningInto", "Cloning into '{0}'...") -f $targetPath
        Write-Host $msg -ForegroundColor ([Constants]::ColorHighlight)
    }

    # Show clone result
    [void] ShowCloneResult([bool]$success, [string]$message) {
        Write-Host ""
        if ($success) {
            $msg = if ($message) { $message } else { $this.GetLoc("Repo.CloneSuccess", "Repository cloned successfully!") }
            Write-Host $msg -ForegroundColor ([Constants]::ColorSuccess)
        } else {
            $msg = if ($message) { $message } else { $this.GetLoc("Repo.CloneFail", "Failed to clone repository.") }
            Write-Host $msg -ForegroundColor ([Constants]::ColorError)
            
            if ($message -and $message -ne $msg) {
                Write-Host $message -ForegroundColor ([Constants]::ColorError)
            }
        }
        Start-Sleep -Seconds 2
    }

    # Show git status warning and ask for confirmation (Yes/No)
    # Returns bool (true = continue with delete, false = cancel)
    [bool] ConfirmGitStatusWarning([RepositoryModel]$repository) {
        $this.Console.ClearForWorkflow()
        
        $header = $this.GetLoc("Repo.DeleteTitle", "DELETE REPOSITORY")
        $this.Renderer.RenderWorkflowHeader($header)
        
        # Repository Details
        $repoLabel = $this.GetLoc("Repo.RepositoryLabel", "Repository")
        $pathLabel = $this.GetLoc("Repo.PathLabel", "Path")
        Write-Host "${repoLabel}: " -NoNewline -ForegroundColor ([Constants]::ColorPrompt)
        Write-Host $repository.Name -ForegroundColor ([Constants]::ColorValue)
        Write-Host "${pathLabel}:       " -NoNewline -ForegroundColor ([Constants]::ColorPrompt)
        Write-Host $repository.FullPath -ForegroundColor ([Constants]::ColorValue)
        Write-Host "=======================================================" -ForegroundColor ([Constants]::ColorSeparator)
        Write-Host ""
        
        # Git Status Warning - WARNING in red
        $warningLabel = $this.GetLoc("Prompt.Warning", "WARNING")
        Write-Host "${warningLabel}: " -NoNewline -ForegroundColor Red
        $gitWarning = $this.GetLoc("Repo.GitStatusWarning", "This repository has uncommitted changes or unpushed commits!")
        Write-Host $gitWarning -ForegroundColor Yellow
        Write-Host ""
        
        # Show git status details with colors
        if ($repository.GitStatus) {
            $status = $repository.GitStatus
            if ($status.HasUncommittedChanges) {
                Write-Host "  - " -NoNewline -ForegroundColor Red
                Write-Host $this.GetLoc("Repo.HasUncommittedChanges", "Has uncommitted changes") -ForegroundColor Yellow
            }
            if ($status.Ahead -gt 0) {
                Write-Host "  - " -NoNewline -ForegroundColor Red
                $aheadMsg = $this.GetLoc("Repo.HasUnpushedCommits", "Has {0} unpushed commit(s)") -f $status.Ahead
                Write-Host $aheadMsg -ForegroundColor Yellow
            }
            Write-Host ""
        }
        
        # Options: No first (default for safety), Yes second
        $noText = $this.GetLoc("Prompt.No", "No")
        $yesText = $this.GetLoc("Prompt.Yes", "Yes")
        $options = @(
            @{ DisplayText = $noText; Value = $false },
            @{ DisplayText = $yesText; Value = $true }
        )
        
        $confirmMsg = $this.GetLoc("Prompt.ContinueAnyway", "Do you want to continue anyway?")
        Write-Host $confirmMsg -ForegroundColor ([Constants]::ColorPrompt)
        Write-Host ""
        
        # Use inline selection loop (similar to OptionSelector but preserving the rendered content above)
        $selectedIndex = 0  # Default to "No" (index 0)
        $running = $true
        $result = $null
        
        try {
            $this.Console.HideCursor()
            $listStartTop = $this.Console.GetCursorTop()
            
            while ($running) {
                $this.Console.SetCursorPosition(0, $listStartTop)
                
                for ($i = 0; $i -lt $options.Count; $i++) {
                    $option = $options[$i]
                    $prefix = if ($i -eq $selectedIndex) { ">" } else { " " }
                    $color = if ($i -eq $selectedIndex) { [Constants]::ColorSelected } else { [Constants]::ColorMenuText }
                    $displayLine = "  $prefix $($option.DisplayText)"
                    $this.Console.WriteLineColored($displayLine, $color)
                }
                
                $this.Console.NewLine()
                $hintText = $this.GetLoc("Prompt.NavigationHint", "Use Arrows to navigate | Enter to select | Q/Esc to cancel")
                $this.Console.WriteLineColored("  $hintText", [Constants]::ColorHint)
                
                $key = $this.Console.ReadKey()
                
                switch ($key.VirtualKeyCode) {
                    ([Constants]::KEY_UP_ARROW) {
                        $selectedIndex = if ($selectedIndex -gt 0) { $selectedIndex - 1 } else { $options.Count - 1 }
                    }
                    ([Constants]::KEY_DOWN_ARROW) {
                        $selectedIndex = if ($selectedIndex -lt ($options.Count - 1)) { $selectedIndex + 1 } else { 0 }
                    }
                    ([Constants]::KEY_ENTER) {
                        $result = $options[$selectedIndex].Value
                        $running = $false
                    }
                    ([Constants]::KEY_Q) { $running = $false }
                    ([Constants]::KEY_ESC) { $running = $false }
                }
            }
        }
        finally {
            $this.Console.HideCursor()
        }
        
        if ($result -eq $true) {
            return $true
        } else {
            $msg = $this.GetLoc("Prompt.Cancelled", "Operation cancelled.")
            Write-Host $msg -ForegroundColor ([Constants]::ColorWarning)
            Start-Sleep -Seconds 1
            return $false
        }
    }

    # Confirm repository deletion by typing the repository name
    # Returns bool (true = delete, false = cancel)
    [bool] ConfirmDelete([RepositoryModel]$repository) {
        $this.Console.ClearForWorkflow()
        
        $header = $this.GetLoc("Repo.DeleteTitle", "DELETE REPOSITORY")
        $this.Renderer.RenderWorkflowHeader($header)
        
        # Repository Details
        Write-Host "Repository: " -NoNewline -ForegroundColor ([Constants]::ColorPrompt)
        Write-Host $repository.Name -ForegroundColor ([Constants]::ColorValue)
        Write-Host "Path:       " -NoNewline -ForegroundColor ([Constants]::ColorPrompt)
        Write-Host $repository.FullPath -ForegroundColor ([Constants]::ColorValue)
        Write-Host "=======================================================" -ForegroundColor ([Constants]::ColorSeparator)
        Write-Host ""
        
        # Warning
        $warningMsg = $this.GetLoc("Repo.DeleteWarning", "WARNING: This will permanently delete the folder and all contents!")
        Write-Host $warningMsg -ForegroundColor Red
        Write-Host ""
        
        # Ask to type repository name
        $confirmMsg = $this.GetLoc("Prompt.TypeRepoName", "Type the repository name to confirm")
        Write-Host "$confirmMsg : " -NoNewline -ForegroundColor Red
        Write-Host $repository.Name -ForegroundColor Cyan
        Write-Host "> " -NoNewline -ForegroundColor ([Constants]::ColorPrompt)
        
        $confirmation = Read-Host
        
        if ($confirmation -eq $repository.Name) {
            return $true
        } else {
            $msg = $this.GetLoc("Prompt.NameMismatch", "Name does not match. Operation cancelled.")
            Write-Host $msg -ForegroundColor ([Constants]::ColorWarning)
            Start-Sleep -Seconds 1
            return $false
        }
    }

    # Show deletion in progress
    [void] ShowDeletingMessage() {
        $msg = $this.GetLoc("Repo.Deleting", "Deleting...")
        Write-Host $msg -ForegroundColor ([Constants]::ColorWarning)
    }

    # Show delete result
    [void] ShowDeleteResult([bool]$success, [string]$errorMsg) {
        if ($success) {
            $msg = $this.GetLoc("Repo.DeleteSuccess", "Repository deleted successfully.")
            Write-Host $msg -ForegroundColor ([Constants]::ColorSuccess)
        } else {
            $msg = $this.GetLoc("Repo.DeleteFail", "Error deleting repository: {0}") -f $errorMsg
            Write-Host $msg -ForegroundColor ([Constants]::ColorError)
            $hint = $this.GetLoc("Repo.DeleteFailHint", "Check if files are open in another program.")
            Write-Host $hint -ForegroundColor ([Constants]::ColorGray)
        }
        Start-Sleep -Seconds 2
    }
}
