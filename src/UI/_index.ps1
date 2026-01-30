# ============================================================================
# UI Layer Index
# ============================================================================
# Dependencies: Config, Models, Services
# ============================================================================

$uiPath = $PSScriptRoot

# ─────────────────────────────────────────────────────────────────────────────
# UI Base & Framework
# ─────────────────────────────────────────────────────────────────────────────
. "$uiPath\Base\ConsoleHelper.ps1"
. "$uiPath\Framework\ConsoleView.ps1"

# ─────────────────────────────────────────────────────────────────────────────
# ViewModels (used by Renderer)
# ─────────────────────────────────────────────────────────────────────────────
. "$uiPath\ViewModels\RepositoryViewModel.ps1"

# ─────────────────────────────────────────────────────────────────────────────
# Renderer & Components
# ─────────────────────────────────────────────────────────────────────────────
. "$uiPath\UIRenderer.ps1"
. "$uiPath\Components\ProgressIndicator.ps1"
. "$uiPath\Components\SelectionOptions.ps1"
. "$uiPath\Components\OptionSelector.ps1"
. "$uiPath\Components\ColorSelector.ps1"
. "$uiPath\Renderers\FilteredListRenderer.ps1"
. "$uiPath\Renderers\IntegrationFlowRenderer.ps1"
. "$uiPath\Components\FilteredListSelector.ps1"
. "$uiPath\Dashboards\IntegrationFlowDashboard.ps1"

# ─────────────────────────────────────────────────────────────────────────────
# UI Services (implements interfaces from Core)
# ─────────────────────────────────────────────────────────────────────────────
. "$uiPath\Services\ConsoleProgressReporter.ps1"
