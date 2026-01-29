# ============================================================================
# Flows Layer Index
# ============================================================================
# Dependencies: Commands, UI Components
# NOTE: GitFlowCommand is here because it orchestrates FlowControllers
# ============================================================================

$flowsPath = $PSScriptRoot

# Base class first
. "$flowsPath\FlowControllerBase.ps1"

# Flow implementations
. "$flowsPath\IntegrationFlowController.ps1"
. "$flowsPath\QuickChangeFlowController.ps1"

# GitFlowCommand (orchestrator) - MUST be loaded after FlowControllers
. "$flowsPath\GitFlowCommand.ps1"
