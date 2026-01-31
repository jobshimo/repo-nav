# scripts/Verify-Startup.ps1
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$mainScript = Join-Path $repoRoot "repo-nav.ps1"

Write-Host "Loading repo-nav.ps1 from $mainScript"
. $mainScript

Write-Host "Building Application Context..."
try {
    $context = [AppBuilder]::Build($repoRoot)
    
    if (-not ($context -is [ApplicationContext])) {
        throw "Context is not of type ApplicationContext. Got: $($context.GetType().FullName)"
    }
    
    Write-Host "Context Type: ApplicationContext [OK]" -ForegroundColor Green
    
    $props = @(
        'RepoManager', 'Renderer', 'Console', 'OptionSelector', 
        'PathManager', 'LocalizationService', 'PreferencesService',
        'ConfigurationService', 'HiddenReposService', 'OnboardingService',
        'ColorSelector', 'Logger'
    )
    
    foreach ($p in $props) {
        if ($null -eq $context.$p) {
            throw "Property '$p' is NULL in ApplicationContext"
        }
        Write-Host "  Property '$p': $($context.$p.GetType().Name) [OK]" -ForegroundColor Gray
    }
    
    Write-Host "Startup Verification PASSED" -ForegroundColor Green
} catch {
    Write-Error "Verification Failed: $_"
    exit 1
}
