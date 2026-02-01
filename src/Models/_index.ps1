# ============================================================================
# Models Layer Index
# ============================================================================
# Dependencies: Config
# ============================================================================

$modelsPath = $PSScriptRoot
$corePath = Join-Path (Split-Path $modelsPath -Parent) "Core"

. "$modelsPath\GitStatusModel.ps1"
. "$modelsPath\AliasInfo.ps1"
. "$modelsPath\RepositoryModel.ps1"
. "$modelsPath\IntegrationFlowModel.ps1"
. "$modelsPath\IntegrationFlowModel.ps1"
. "$modelsPath\SelectionOptions.ps1"

# Preferences Models
. "$modelsPath\Preferences\PathAlias.ps1"
. "$modelsPath\Preferences\RepositoryPreferences.ps1"
. "$modelsPath\Preferences\GeneralPreferences.ps1"
. "$modelsPath\Preferences\GitPreferences.ps1"
. "$modelsPath\Preferences\HiddenPreferences.ps1"
. "$modelsPath\Preferences\MenuSectionsPreferences.ps1"
. "$modelsPath\Preferences\DisplayPreferences.ps1"
. "$modelsPath\Preferences\PreferenceUpdateResult.ps1"
. "$modelsPath\Preferences\UserPreferences.ps1"

. "$corePath\Common\OperationResult.ps1"
