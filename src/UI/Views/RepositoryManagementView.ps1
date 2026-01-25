class RepositoryManagementView {
    [ConsoleHelper] $Console
    [LocalizationService] $LocalizationService
    [UIRenderer] $Renderer

    RepositoryManagementView([ConsoleHelper]$console, [LocalizationService]$localizationService, [UIRenderer]$renderer) {
        $this.Console = $console
        $this.LocalizationService = $localizationService
        $this.Renderer = $renderer
    }

    # Helper method for localization
    hidden [string] GetLoc([string]$key, [string]$default) {
        if ($this.LocalizationService) { return $this.LocalizationService.Get($key) }
        return $default
    }

    # Prompt user for cloning information
    # Returns hashtable @{ Url = "url"; Name = "name" } or $null if cancelled
    [hashtable] GetCloneDetails() {
        $this.Console.ClearForWorkflow()
        
        $header = $this.GetLoc("Repo.CloneTitle", "CLONE REPOSITORY")
        $this.Renderer.RenderWorkflowHeader($header)
        
        # Get URL
        Write-Host "GitHub URL (https://... or git@...): " -NoNewline -ForegroundColor ([Constants]::ColorPrompt)
        $url = Read-Host
        
        if ([string]::IsNullOrWhiteSpace($url)) {
            $msg = $this.GetLoc("Prompt.Cancelled", "Operation cancelled.")
            Write-Host $msg -ForegroundColor ([Constants]::ColorWarning)
            Start-Sleep -Seconds 1
            return $null
        }
        
        # Extract default name
        $defaultName = $url.Split('/')[-1].Replace('.git', '')
        
        # Get Custom Name
        Write-Host "Target folder name (Enter = '$defaultName'): " -NoNewline -ForegroundColor ([Constants]::ColorPrompt)
        $customName = Read-Host
        
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

    # Confirm repository deletion
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
        $confirmMsg = $this.GetLoc("Prompt.DeleteConfirm", "Type 'DELETE' to confirm")
        
        Write-Host $warningMsg -ForegroundColor Red
        Write-Host ""
        Write-Host "$confirmMsg : " -NoNewline -ForegroundColor Red
        
        $confirmation = Read-Host
        
        if ($confirmation -eq "DELETE") {
            return $true
        } else {
            $msg = $this.GetLoc("Prompt.Cancelled", "Operation cancelled.")
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
