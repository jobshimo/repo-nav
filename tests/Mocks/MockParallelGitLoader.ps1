
# tests/Mocks/MockParallelGitLoader.ps1

class MockParallelGitLoader : ParallelGitLoader {
    [int] $CallCount
    
    MockParallelGitLoader() {
        # Base constructor might do nothing significant or init runspace pool
        # If base constructor connects to runspace, we might need to be careful.
        # Check source if needed. Assuming safe instantiation.
        $this.CallCount = 0
    }
    
    [void] LoadGitStatusParallel([array]$repositories, [scriptblock]$progressCallback) {
        $this.CallCount++
        
        # Simulate synchronous loading
        foreach ($repo in $repositories) {
            # In a real mock we might set a dummy status
            # For now just pretend we did work
            $repo.SetGitStatus([GitStatusModel]::new())
        }
    }
}
