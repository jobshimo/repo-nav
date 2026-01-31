# ============================================================================
# Flows Layer Index
# ============================================================================
# Dependencies: Commands, UI Components
# NOTE: GitFlowCommand is here because it orchestrates FlowControllers
# ============================================================================

$flowsPath = $PSScriptRoot

# Base class first
if (-not ([System.Management.Automation.PSTypeName]'FlowControllerBase').Type) {
    . "$flowsPath\FlowControllerBase.ps1"
}

# Flow implementations
if (-not ([System.Management.Automation.PSTypeName]'IntegrationFlowController').Type) {
    . "$flowsPath\IntegrationFlowController.ps1"
}
if (-not ([System.Management.Automation.PSTypeName]'QuickChangeFlowController').Type) {
    . "$flowsPath\QuickChangeFlowController.ps1"
}

# GitFlowCommand (orchestrator) - MUST be loaded after FlowControllers
if (-not ([System.Management.Automation.PSTypeName]'GitFlowCommand').Type) {
    . "$flowsPath\GitFlowCommand.ps1"
}
