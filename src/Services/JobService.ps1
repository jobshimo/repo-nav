class JobService : IJobService {
    [object] StartJob([scriptblock]$ScriptBlock, [object[]]$ArgumentList) {
        return Start-Job -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
    }
    [object] WaitJob([object]$Job) {
        return Wait-Job -Job $Job
    }
    [object] ReceiveJob([object]$Job) {
        return Receive-Job -Job $Job
    }
    [void] RemoveJob([object]$Job, [bool]$Force) {
        if ($Force) {
            Remove-Job -Job $Job -Force -ErrorAction SilentlyContinue
        } else {
            Remove-Job -Job $Job -ErrorAction SilentlyContinue
        }
    }
}
