class OperationResult {
    [bool] $Success
    [object] $Data
    [string] $Message
    [object] $ErrorDetails

    OperationResult() {}

    static [OperationResult] Ok() {
        return [OperationResult]::Ok($null, "")
    }

    static [OperationResult] Ok([object]$data) {
        return [OperationResult]::Ok($data, "")
    }

    static [OperationResult] Ok([object]$data, [string]$message) {
        $result = [OperationResult]::new()
        $result.Success = $true
        $result.Data = $data
        $result.Message = $message
        return $result
    }

    static [OperationResult] Fail([string]$message) {
        return [OperationResult]::Fail($message, $null)
    }

    static [OperationResult] Fail([string]$message, [object]$errorObj) {
        $result = [OperationResult]::new()
        $result.Success = $false
        $result.Message = $message
        $result.ErrorDetails = $errorObj
        return $result
    }
}
