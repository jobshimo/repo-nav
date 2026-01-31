class IProgressIndicator : IProgressReporter {
    [void] ShowLoadingDots([string]$message, [scriptblock]$action) {}
    [void] RenderProgressBar([string]$message, [int]$current, [int]$total) {}
    [void] CompleteProgressBar() {}
}
