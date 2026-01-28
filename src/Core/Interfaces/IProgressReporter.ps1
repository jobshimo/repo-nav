<#
.SYNOPSIS
    Interface for reporting progress
    
.DESCRIPTION
    Abstractions for reporting progress to allow decoupling Core from UI.
#>

class IProgressReporter {
    [void] Report([string]$message, [int]$current, [int]$total) {
        # Virtual method, to be overridden
    }
    
    [void] Complete() {
        # Virtual method, to be overridden
    }
}
