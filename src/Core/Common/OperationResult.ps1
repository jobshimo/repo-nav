class OperationResult {
    [bool] $Success
    [object] $Data
    [string] $Message
    [object] $ErrorDetails

    OperationResult() {}

    static [OperationResult] Ok([object]$data = $null, [string]$message = "") {
        $result = [OperationResult]::new()
        $result.Success = $true
        $result.Data = $data
        $result.Message = $message
        return $result
    }

    static [OperationResult] Fail([string]$message, [object]$errorObj = $null) {
        $result = [OperationResult]::new()
        $result.Success = $false
        $result.Message = $message
        $result.ErrorDetails = $errorObj
        return $result
    }
}
