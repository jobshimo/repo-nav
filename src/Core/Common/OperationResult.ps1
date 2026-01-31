<#
.SYNOPSIS
    Unified result wrapper for operations that may succeed or fail
    
.DESCRIPTION
    Provides a consistent return type for all operations, eliminating
    mixed error handling patterns (throw/Write-Error/return null).
    
    Following Result Pattern (Railway Oriented Programming):
    - Success path: Ok() with optional data
    - Failure path: Fail() with error message and details
    
.EXAMPLE
    [OperationResult] DoSomething() {
        try {
            $data = Get-SomeData
            return [OperationResult]::Ok($data, "Success!")
        } catch {
            return [OperationResult]::Fail("Failed: $($_.Exception.Message)", $_)
        }
    }
#>

class OperationResult {
    [bool] $Success
    [object] $Data
    [string] $Message
    [string] $ErrorCode
    [object] $ErrorDetails

    OperationResult() {}

    # Success factory methods
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
        $result.ErrorCode = $null
        return $result
    }

    # Failure factory methods
    static [OperationResult] Fail([string]$message) {
        return [OperationResult]::Fail($message, $null)
    }

    static [OperationResult] Fail([string]$message, [object]$errorObj) {
        return [OperationResult]::Fail($message, $null, $errorObj)
    }
    
    static [OperationResult] Fail([string]$message, [string]$errorCode, [object]$errorObj) {
        $result = [OperationResult]::new()
        $result.Success = $false
        $result.Message = $message
        $result.ErrorCode = $errorCode
        $result.ErrorDetails = $errorObj
        return $result
    }
    
    # Helper: Check if failed
    [bool] IsFailed() {
        return -not $this.Success
    }
    
    # Helper: Get error message or default
    [string] GetErrorMessage([string]$defaultMessage) {
        if ($this.IsFailed() -and -not [string]::IsNullOrEmpty($this.Message)) {
            return $this.Message
        }
        return $defaultMessage
    }
}
