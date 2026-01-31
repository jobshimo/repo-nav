Import-Module Pester -ErrorAction Stop

$config = [PesterConfiguration]::Default
$config.Run.Path = '.\tests\Pester\'
$config.Output.Verbosity = 'Normal'
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = '.\src\'
$config.CodeCoverage.OutputFormat = 'Jacoco'
$config.CodeCoverage.OutputPath = 'coverage.xml'
$config.CodeCoverage.CoveragePercentTarget = 80 # High target to force fail

Write-Host "Invoking Pester..."
Invoke-Pester -Configuration $config

Write-Host "Last Exit Code: $LASTEXITCODE"

if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILURE DETECTED" -ForegroundColor Red
} else {
    Write-Host "SUCCESS DETECTED (Unexpected)" -ForegroundColor Yellow
}
