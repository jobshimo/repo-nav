# ═══════════════════════════════════════════════════════════════════════════
# DEV ONLY: This file is NOT included in the bundle ($loadOrder)
# ═══════════════════════════════════════════════════════════════════════════

class DevToolsCommand {
    <#
    .SYNOPSIS
        Development-only tools. NOT included in production bundle.
    .DESCRIPTION
        This class provides development utilities like building the bundle.
        It only exists when running from source (not from bundled distribution).
    #>
    
    static [void] BuildBundle([ConsoleHelper]$console) {
        $scriptRoot = [Constants]::ScriptRoot
        $buildScript = Join-Path $scriptRoot "Build-Bundle.ps1"
        
        if (-not (Test-Path $buildScript)) {
            $console.WriteLineColored("  Build script not found: $buildScript", [ConsoleColor]::Red)
            Start-Sleep -Seconds 2
            return
        }
        
        $console.ClearScreen()
        Write-Host ""
        Write-Host "  ========================================" -ForegroundColor Cyan
        Write-Host "    BUILDING DISTRIBUTION BUNDLE..." -ForegroundColor Cyan
        Write-Host "  ========================================" -ForegroundColor Cyan
        Write-Host ""
        
        try {
            # Execute the build script
            & $buildScript -Minify
            
            Write-Host ""
            Write-Host "  Build complete! Press any key to continue..." -ForegroundColor Green
        }
        catch {
            Write-Host ""
            Write-Host "  Build failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "  Press any key to continue..." -ForegroundColor Yellow
        }
        
        $console.ReadKey() | Out-Null
    }
    
    static [bool] IsDevEnvironment() {
        $srcPath = Join-Path ([Constants]::ScriptRoot) "src"
        return (Test-Path $srcPath)
    }
}
