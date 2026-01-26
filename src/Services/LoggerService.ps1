class LoggerService {
    [string] $LogFilePath

    LoggerService([string]$scriptRoot) {
        $this.LogFilePath = Join-Path $scriptRoot "repo-nav.error.log"
    }

    [void] LogError([Exception]$ex) {
        try {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $message = "[$timestamp] [ERROR] $($ex.GetType().Name): $($ex.Message)"
            $stackTrace = $ex.ScriptStackTrace
            if ([string]::IsNullOrEmpty($stackTrace)) {
                $stackTrace = $ex.StackTrace
            }
            
            $logContent = "$message`n$stackTrace`n----------------------------------------"
            
            Add-Content -Path $this.LogFilePath -Value $logContent -ErrorAction SilentlyContinue
        }
        catch {
            # Fail silently, to ensure the logger never crashes the app
        }
    }
}
