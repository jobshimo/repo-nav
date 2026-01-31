# ============================================================================
# UI Layer Index
# ============================================================================
# Dependencies: Config, Models, Services
# ============================================================================

$uiPath = $PSScriptRoot

# ─────────────────────────────────────────────────────────────────────────────
# UI Base & Framework
# ─────────────────────────────────────────────────────────────────────────────
if (-not ([System.Management.Automation.PSTypeName]'ConsoleHelper').Type) {
    . "$uiPath\Base\ConsoleHelper.ps1"
}
if (-not ([System.Management.Automation.PSTypeName]'ViewportManager').Type) {
    . "$uiPath\Base\ViewportManager.ps1"
}
# ConsoleView moved to Core/Common, loaded in Layer 3


# ─────────────────────────────────────────────────────────────────────────────
# ViewModels (used by Renderer)
# ─────────────────────────────────────────────────────────────────────────────
if (-not ([System.Management.Automation.PSTypeName]'RepositoryViewModel').Type) {
    . "$uiPath\ViewModels\RepositoryViewModel.ps1"
}

# ─────────────────────────────────────────────────────────────────────────────
# Renderer & Components
# ─────────────────────────────────────────────────────────────────────────────
if (-not ([System.Management.Automation.PSTypeName]'UIRenderer').Type) {
    . "$uiPath\UIRenderer.ps1"
}
if (-not ([System.Management.Automation.PSTypeName]'ProgressIndicator').Type) {
    . "$uiPath\Components\ProgressIndicator.ps1"
}
# SelectionOptions moved to Models, loaded in Layer 2

if (-not ([System.Management.Automation.PSTypeName]'OptionSelector').Type) {
    . "$uiPath\Components\OptionSelector.ps1"
}
if (-not ([System.Management.Automation.PSTypeName]'ColorSelector').Type) {
    . "$uiPath\Components\ColorSelector.ps1"
}
if (-not ([System.Management.Automation.PSTypeName]'FilteredListRenderer').Type) {
    . "$uiPath\Renderers\FilteredListRenderer.ps1"
}
if (-not ([System.Management.Automation.PSTypeName]'IntegrationFlowRenderer').Type) {
    . "$uiPath\Renderers\IntegrationFlowRenderer.ps1"
}
if (-not ([System.Management.Automation.PSTypeName]'FilteredListSelector').Type) {
    . "$uiPath\Components\FilteredListSelector.ps1"
}
if (-not ([System.Management.Automation.PSTypeName]'IntegrationFlowDashboard').Type) {
    . "$uiPath\Dashboards\IntegrationFlowDashboard.ps1"
}

# ─────────────────────────────────────────────────────────────────────────────
# Controllers (Refactored)
# ─────────────────────────────────────────────────────────────────────────────
# . "$uiPath\Controllers\PreferencesActionDispatcher.ps1" (Moved to repo-nav.ps1 Layer 8)
# . "$uiPath\Controllers\PreferencesMenuRenderer.ps1"     (Moved to repo-nav.ps1 Layer 8)
# . "$uiPath\Controllers\PreferencesMenuController.ps1"   (Moved to repo-nav.ps1 Layer 8)

# ─────────────────────────────────────────────────────────────────────────────
# UI Services (implements interfaces from Core)
# ─────────────────────────────────────────────────────────────────────────────
if (-not ([System.Management.Automation.PSTypeName]'ConsoleProgressReporter').Type) {
    . "$uiPath\Services\ConsoleProgressReporter.ps1"
}
