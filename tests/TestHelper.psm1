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
        . $fullPath
    } else {
        Write-Error "Could not find file: $fullPath"
    }
}

function Get-ProjectRoot {
    return $script:projectRoot
}
