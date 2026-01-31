
# tests/Mocks/MockProgressReporter.ps1

class MockProgressReporter : IProgressReporter {
    [int] $ReportCalls
    
    MockProgressReporter() {
        $this.ReportCalls = 0
    }
    
    [void] Report([string]$operation, [int]$percentComplete, [int]$totalOperations) {
        $this.ReportCalls++
    }
    
    [void] Complete() {
        # Nothing
    }
}
