# ============================================================================
# Startup Layer Index
# ============================================================================
# Dependencies: Everything (loaded last)
# ============================================================================

$startupPath = $PSScriptRoot
$appPath = Join-Path (Split-Path $startupPath -Parent) "App"

. "$startupPath\ServiceRegistry.ps1"
. "$appPath\AppBuilder.ps1"
