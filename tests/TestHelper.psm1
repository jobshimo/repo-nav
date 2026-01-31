# TestHelper.psm1
# Provides utilities for loading dependencies in isolation for Unit Tests

$script:projectRoot = Resolve-Path "$PSScriptRoot\..\src"

function Import-ProjectFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    $fullPath = Join-Path $script:projectRoot $Path
    if (Test-Path $fullPath) {
        # Dot-source into the global scope to ensure Classes are visible to Pester
        . $fullPath
    } else {
        Write-Error "Could not find file: $fullPath"
    }
}

function Get-ProjectRoot {
    return $script:projectRoot
}
