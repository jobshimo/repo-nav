class ILocalizationService {
    [void] LoadFallback() {}
    [void] SetLanguage([string]$languageCode) {}
    [void] LoadLanguage([string]$languageCode) {}
    [string] Get([string]$key) { return "" }
    [string] Get([string]$key, [object[]]$args) { return "" }
    [string] GetCurrentLanguage() { return "" }
    [string[]] GetAvailableLanguages() { return @() }
}
