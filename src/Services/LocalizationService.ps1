<#
.SYNOPSIS
    LocalizationService - Manages application localization (i18n)
    
.DESCRIPTION
    Following SOLID principles:
    - SRP: Only responsible for loading and serving translation strings
    - OCP: New languages can be added just by adding JSON files in Resources/i18n
    
    Features:
    - JSON-based translation files
    - Fallback to English for missing keys
    - String formatting support (e.g. "Values: {0}, {1}")
#>

class LocalizationService {
    [hashtable] $Translations
    [hashtable] $FallbackTranslations
    [string] $CurrentLanguage
    [string] $ResourcesPath
    
    LocalizationService() {
        $this.CurrentLanguage = "en"
        $this.Translations = @{}
        $this.FallbackTranslations = @{}
        $this.ResourcesPath = Join-Path ([Constants]::ScriptRoot) "src\Resources\i18n"
        
        # Always load fallback (English) first to ensure we have it
        $this.LoadFallback()
        
        # Load default
        $this.LoadLanguage("en")
    }
    
    [void] LoadFallback() {
        $fallbackPath = Join-Path $this.ResourcesPath "en.json"
        if (Test-Path $fallbackPath) {
            try {
                $content = Get-Content $fallbackPath -Raw -Encoding UTF8
                $json = ConvertFrom-Json $content
                
                # Convert PSObject to Hashtable for faster lookup
                foreach ($prop in $json.PSObject.Properties) {
                    $this.FallbackTranslations[$prop.Name] = $prop.Value
                }
            }
            catch {
                Write-Warning "Failed to load fallback translations (en.json): $_"
            }
        }
    }

    [void] SetLanguage([string]$languageCode) {
        if ([string]::IsNullOrWhiteSpace($languageCode)) {
            $languageCode = "en"
        }
        
        $this.CurrentLanguage = $languageCode
        $this.LoadLanguage($languageCode)
    }
    
    [void] LoadLanguage([string]$languageCode) {
        $filePath = Join-Path $this.ResourcesPath "$languageCode.json"
        
        $this.Translations.Clear()
        
        if (Test-Path $filePath) {
            try {
                $content = Get-Content $filePath -Raw -Encoding UTF8
                $json = ConvertFrom-Json $content
                
                foreach ($prop in $json.PSObject.Properties) {
                    $this.Translations[$prop.Name] = $prop.Value
                }
            }
            catch {
                Write-Warning "Failed to load translations for '$languageCode': $_"
                # If loading fails, we rely on empty Translations, falling back to FallbackTranslations
            }
        } elseif ($languageCode -ne "en") {
            Write-Warning "Translation file not found: $filePath"
        }
    }
    
    [string] Get([string]$key) {
        if ([string]::IsNullOrEmpty($key)) { return "" }
        
        # Try current language
        if ($this.Translations.ContainsKey($key)) {
            return $this.Translations[$key]
        }
        
        # Try fallback language
        if ($this.FallbackTranslations.ContainsKey($key)) {
            return $this.FallbackTranslations[$key]
        }
        
        # Return key as last resort to identify missing translations in UI
        return "[$key]"
    }
    
    [string] Get([string]$key, [object[]]$args) {
        $formatString = $this.Get($key)
        
        if ($null -eq $args -or $args.Count -eq 0) {
            return $formatString
        }
        
        try {
            return [string]::Format($formatString, $args)
        }
        catch {
            return "$formatString (Format Error)"
        }
    }
    
    [string] GetCurrentLanguage() {
        return $this.CurrentLanguage
    }
    
    [string[]] GetAvailableLanguages() {
        if (-not (Test-Path $this.ResourcesPath)) {
            return @("en")
        }
        
        return Get-ChildItem $this.ResourcesPath -Filter "*.json" | 
               Select-Object -ExpandProperty BaseName
    }
}
