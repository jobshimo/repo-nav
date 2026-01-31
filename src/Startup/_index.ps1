# ============================================================================
# Startup Layer Index
# ============================================================================
# Dependencies: Everything (loaded last)
# ============================================================================

$startupPath = $PSScriptRoot
$appPath = Join-Path (Split-Path $startupPath -Parent) "App"

. "$appPath\AppBuilder.ps1"
