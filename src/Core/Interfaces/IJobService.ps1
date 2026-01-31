class IJobService {
    [object] StartJob([scriptblock]$ScriptBlock, [object[]]$ArgumentList) { return $null }
    [object] WaitJob([object]$Job) { return $null }
    [object] ReceiveJob([object]$Job) { return $null }
    [void] RemoveJob([object]$Job, [bool]$Force) {}
}
