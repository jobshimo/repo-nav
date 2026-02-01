<#
.SYNOPSIS
    IIntegrationFlowDashboard - Interface for integration flow dashboard
#>
class IIntegrationFlowDashboard {
    [void] RenderFull([IntegrationFlowModel]$model, [int]$selectedIndex) {}
    [void] UpdateSelection([IntegrationFlowModel]$model, [int]$newIndex) {}
    [void] UpdateValue([IntegrationFlowModel]$model, [int]$index) {}
}
