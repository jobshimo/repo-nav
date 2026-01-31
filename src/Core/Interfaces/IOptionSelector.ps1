class IOptionSelector : ConsoleView {
    IOptionSelector() : base() {}
    IOptionSelector([IConsoleHelper]$console) : base($console) {}

    [object] Show([SelectionOptions]$config) { return $null }
    [bool] SelectYesNo([string]$question, [object]$localizationService, [bool]$clearScreen) { return $false }
    [bool] SelectYesNo([string]$question) { return $false }
    [bool] SelectYesNo([string]$question, [bool]$clearScreen) { return $false }
}
