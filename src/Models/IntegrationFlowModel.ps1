
class IntegrationFlowModel {
    [string] $TargetBranch = ""
    [bool] $TargetBranchValid = $false
    
    [string] $NewBranchName = ""
    [bool] $NewBranchNameValid = $false
    
    [string] $SourceBranch = ""
    [bool] $SourceBranchValid = $false

    # Validation Logic
    [bool] IsReadyToExecute() {
        return $this.TargetBranchValid -and 
               $this.NewBranchNameValid -and 
               $this.SourceBranchValid
    }
}
