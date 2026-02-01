<#
.SYNOPSIS
    IIntegrationFlowRenderer - Interface for integration flow renderer
#>
class IIntegrationFlowRenderer {
    [void] RenderInteractiveDashboard([hashtable]$flowState, [int]$selectedIndex) {}
    [void] RenderExecutionStatus([string]$message, [bool]$success) {}
}
