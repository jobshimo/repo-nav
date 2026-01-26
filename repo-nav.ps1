<#
.SYNOPSIS
    Interactive repository navigator for managing multiple Git repositories

.DESCRIPTION
    Navigate between repositories, manage aliases, install/remove node_modules,
    clone repositories from GitHub, and delete repositories with safety checks.
    
    This version has been refactored using SOLID principles and OOP:
    - Single Responsibility Principle: Each class has one clear purpose
    - Open/Closed Principle: Easy to extend without modifying existing code
    - Liskov Substitution Principle: Proper inheritance and composition
    - Interface Segregation Principle: Specialized interfaces for UI, Services
    - Dependency Inversion Principle: All classes depend on abstractions

.PARAMETER BasePath
    The base path where repositories are located. If not provided, uses the default from Constants.

.EXAMPLE
    .\repo-nav.ps1
    Launches with default path from Constants.ps1

.EXAMPLE
    .\repo-nav.ps1 -BasePath "C:\Projects"
    Launches with custom repositories path

.INSTALLATION
    Run .\Install.ps1 for interactive setup

.USAGE
    Type your command (e.g., 'list') from any directory to launch the repository navigator

.CONTROLS
    Navigation: Arrows | Enter=open | Q=quit
    Aliases:    E=set | R=remove
    Modules:    I=install | X=remove
    Repository: C=clone | Del=delete
    Git Status: L=load current | G=load all

.NOTES
    Author: Martin Miguel Bernal Garcia
    Version: 2.0 (Refactored with SOLID/OOP)
    Requires: PowerShell 5.1+, Git, npm (for node_modules management)
#>

# Parameters must be at the top of the script
param(
    [Parameter(Mandatory=$false)]
    [string]$BasePath
)

#region Import Modules
# Get script directory
$scriptRoot = $PSScriptRoot
$srcPath = Join-Path $scriptRoot "src"

# 1. Load Dependency Loader
try {
    . "$srcPath\Core\DependencyLoader.ps1"
}
catch {
    Write-Error "Failed to load DependencyLoader: $_"
    exit 1
}

# 2. Load all application dependencies
# This script is dot-sourced, so it runs in the current (script) scope.
# Note that DependencyLoader will inherit variables from this scope, but calculate
# its own paths based on PSScriptRoot relative to itself.
# We don't need to pass params if it self-calculates, or we could pass $srcPath.
# The previous version used [DependencyLoader]::Load, now we use simple dot-sourcing.
. "$srcPath\Core\DependencyLoader.ps1"

# 3. Initialize Constants (Requires loaded classes)
[Constants]::Initialize($scriptRoot)
#endregion

#region Main Entry Point
# Start-RepositoryNavigator function is replaced by Bootstrapper class
#endregion

#region Execute
# When script is run directly (not dot-sourced), start the navigator
if ($MyInvocation.InvocationName -ne '.') {
    # Use provided BasePath or default from Constants
    if (-not $BasePath) {
        $BasePath = [Constants]::ReposBasePath
    }
    
    # Start the navigator via Bootstrapper
    [Bootstrapper]::Start($BasePath)
}
#endregion
