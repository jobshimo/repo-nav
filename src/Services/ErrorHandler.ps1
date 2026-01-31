<#
.SYNOPSIS
    Centralized error handling service
    
.DESCRIPTION
    Provides consistent error handling throughout the application.
    Eliminates mixed patterns (throw/Write-Error/return null).
    
    Following Single Responsibility Principle:
    - Logs errors
    - Formats user-friendly messages
    - Returns OperationResult
    
.EXAMPLE
    $result = $this.ErrorHandler.TryCatch({
        # Risky operation
        Get-SomeData
    }, "Failed to get data")
    
    if ($result.IsFailed()) {
        $this.Renderer.RenderError($result.Message)
    }
#>

class ErrorHandler {
    [LoggerService] $Logger
    [LocalizationService] $Localization
    
    # Constructor
    ErrorHandler([LoggerService]$logger, [LocalizationService]$localization) {
        $this.Logger = $logger
        $this.Localization = $localization
    }
    
    <#
    .SYNOPSIS
        Executes a script block and returns an OperationResult
        
    .PARAMETER scriptBlock
        The code to execute
        
    .PARAMETER errorMessage
        User-friendly error message (will be localized if key provided)
        
    .PARAMETER errorCode
        Optional error code for categorization
        
    .RETURNS
        OperationResult - Success with data or Fail with error details
    #>
    [OperationResult] TryCatch([scriptblock]$scriptBlock, [string]$errorMessage) {
        return $this.TryCatch($scriptBlock, $errorMessage, $null)
    }
    
    [OperationResult] TryCatch([scriptblock]$scriptBlock, [string]$errorMessage, [string]$errorCode) {
        try {
            $result = & $scriptBlock
            return [OperationResult]::Ok($result)
        }
        catch {
            # Log technical error
            $this.Logger.LogError($_)
            
            # Return user-friendly error
            $message = $this.GetLocalizedMessage($errorMessage)
            return [OperationResult]::Fail($message, $errorCode, $_)
        }
    }
    
    <#
    .SYNOPSIS
        Wraps a nullable result in an OperationResult
        
    .DESCRIPTION
        Converts null/empty results to failures without throwing exceptions
    #>
    [OperationResult] WrapResult([object]$result, [string]$errorIfNull) {
        if ($null -eq $result -or ($result -is [string] -and [string]::IsNullOrEmpty($result))) {
            return [OperationResult]::Fail($this.GetLocalizedMessage($errorIfNull))
        }
        return [OperationResult]::Ok($result)
    }
    
    <#
    .SYNOPSIS
        Validates a condition and returns OperationResult
    #>
    [OperationResult] Validate([bool]$condition, [string]$errorMessage) {
        if (-not $condition) {
            return [OperationResult]::Fail($this.GetLocalizedMessage($errorMessage))
        }
        return [OperationResult]::Ok()
    }
    
    <#
    .SYNOPSIS
        Logs an error without throwing
        
    .DESCRIPTION
        Use this for non-critical errors that shouldn't stop execution
    #>
    [void] LogWarning([string]$message, [object]$exception) {
        if ($null -ne $exception) {
            $this.Logger.LogError($exception)
        }
        $this.Logger.LogWarning($message)
    }
    
    <#
    .SYNOPSIS
        Gets a localized error message
        
    .DESCRIPTION
        If the message is a localization key, translates it.
        Otherwise returns the message as-is.
    #>
    hidden [string] GetLocalizedMessage([string]$message) {
        if ([string]::IsNullOrEmpty($message)) {
            return $this.Localization.Get("Error.Generic")
        }
        
        # Check if it's a localization key (contains dots like "Error.Npm.NotFound")
        if ($message -match '^\w+\.\w+') {
            return $this.Localization.Get($message)
        }
        
        return $message
    }
    
    <#
    .SYNOPSIS
        Converts exceptions to OperationResult
        
    .DESCRIPTION
        Helper for legacy code that throws exceptions
    #>
    [OperationResult] FromException([System.Management.Automation.ErrorRecord]$error) {
        return $this.FromException($error, "Error.Generic")
    }
    
    [OperationResult] FromException([System.Management.Automation.ErrorRecord]$error, [string]$message) {
        $this.Logger.LogError($error)
        $localizedMessage = $this.GetLocalizedMessage($message)
        return [OperationResult]::Fail($localizedMessage, $null, $error)
    }
}
