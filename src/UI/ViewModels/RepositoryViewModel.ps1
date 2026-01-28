class RepositoryViewModel {
    [RepositoryModel] $Model
    [PSCustomObject] $Preferences
    
    RepositoryViewModel([RepositoryModel]$model, [PSCustomObject]$preferences) {
        $this.Model = $model
        $this.Preferences = $preferences
    }
    
    [ConsoleColor] GetNameColor([bool]$isSelected) {
        if ($this.Model.IsContainer) {
            return [Constants]::ColorHighlight
        } 
        
        if (-not $this.Model.HasNodeModules) { 
            return [Constants]::ColorRepoWithoutModules
        } 
        
        if ($isSelected) { 
            $bgColor = $this.Preferences.display.selectedBackground
            return [Constants]::GetTextColorForBackground($bgColor)
        } 
        
        return [Constants]::ColorUnselected
    }
    
    [string] GetPrefix([bool]$isSelected) {
        if ($isSelected) { return "  > " }
        return "    "
    }
    
    [hashtable] GetGitStatusDisplay() {
        $gitStatus = $this.Model.GitStatus
        
        if (-not $gitStatus -or -not $gitStatus.IsGitRepo) {
            return @{
                Symbol = [Constants]::GitSymbolNotRepo
                Color = ([Constants]::ColorGitUnknown)
                Description = "Not a git repository"
            }
        }
        
        if ($gitStatus.HasUncommittedChanges) {
            return @{
                Symbol = [Constants]::GitSymbolUncommitted
                Color = ([Constants]::ColorGitUncommitted)
                Description = "Uncommitted changes"
            }
        }
        
        if ($gitStatus.HasUnpushedCommits) {
            return @{
                Symbol = [Constants]::GitSymbolUnpushed
                Color = ([Constants]::ColorGitUnpushed)
                Description = "Unpushed commits"
            }
        }
        
        return @{
            Symbol = [Constants]::GitSymbolClean
            Color = ([Constants]::ColorGitClean)
            Description = "Clean repository"
        }
    }
}
