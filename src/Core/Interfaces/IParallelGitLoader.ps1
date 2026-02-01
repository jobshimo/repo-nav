
# src/Core/Interfaces/IParallelGitLoader.ps1

class IParallelGitLoader {
    [void] LoadGitStatusParallel([array]$repositories, [scriptblock]$progressCallback) {}
}
