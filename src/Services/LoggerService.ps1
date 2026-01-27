class LoggerService {
    [string] $LogFilePath

    LoggerService([string]$scriptRoot) {
        $this.LogFilePath = Join-Path $scriptRoot "repo-nav.error.log"
    }

    [void] LogError([object]$errorItem) {
        try {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            
            # Determine error type and extract info
            $ex = $errorItem
            if ($errorItem -is [System.Management.Automation.ErrorRecord]) {
                $ex = $errorItem.Exception
            }
            
            $message = "[$timestamp] [ERROR] "
            $stackTrace = ""
            
            if ($null -ne $ex) {
                 $message += "$($ex.GetType().Name): $($ex.Message)"
                 $stackTrace = $ex.ScriptStackTrace
                 if ([string]::IsNullOrEmpty($stackTrace)) {
                     $stackTrace = $ex.StackTrace
                 }
            } else {
                 $message += "Unknown Error: $errorItem"
            }
            
            $logContent = "$message`n$stackTrace`n----------------------------------------"
            
            Add-Content -Path $this.LogFilePath -Value $logContent -ErrorAction SilentlyContinue
        }
        catch {
            # Fail silently, to ensure the logger never crashes the app
        }
    }
}
