<#
.SYNOPSIS
    Constants class - Single source of truth for all application constants
    
.DESCRIPTION
    Following SRP (Single Responsibility Principle):
    This class only holds constants and provides static access to them.
    User-specific configuration is loaded from .repo-config.json
#>

class Constants {
    # Paths (loaded from config file)
    static [string] $ReposBasePath
    static [string] $UserName
    static [string] $AliasFileName = ".repo-aliases.json"
    
    # Script root path
    static [string] $ScriptRoot
    
    # Virtual Key Codes
    static [int] $KEY_UP_ARROW = 38
    static [int] $KEY_DOWN_ARROW = 40
    static [int] $KEY_ENTER = 13
    static [int] $KEY_E = 69
    static [int] $KEY_R = 82
    static [int] $KEY_Q = 81
    static [int] $KEY_ESC = 27
    static [int] $KEY_ESCAPE = 27
    static [int] $KEY_TAB = 9
    static [int] $KEY_BACKSPACE = 8
    static [int] $KEY_I = 73
    static [int] $KEY_X = 88
    static [int] $KEY_DELETE = 46
    static [int] $KEY_C = 67
    static [int] $KEY_G = 71
    static [int] $KEY_L = 76
    static [int] $KEY_F = 70
    static [int] $KEY_U = 85
    static [int] $KEY_LEFT_ARROW = 37
    static [int] $KEY_RIGHT_ARROW = 39
    static [int] $KEY_N = 78
    static [int] $KEY_B = 66
    static [int] $KEY_HOME = 36
    static [int] $KEY_END = 35
    
    # UI Constants
    static [int] $CursorStartLine = 10
    static [int] $UIWidth = 90  # New standardized width for separators
    
    # Focus Mode Constants
    static [string] $FocusInput = "input"
    static [string] $FocusList = "list"
    static [string] $FocusHeader = "header"
    
    # Git Status Symbols
    static [string] $GitSymbolClean = [char]0x2713      # ✓
    static [string] $GitSymbolUncommitted = [char]0x25CF # ●
    static [string] $GitSymbolUnpushed = [char]0x2191    # ↑
    static [string] $GitSymbolUnknown = "?"
    
    # Favorite Symbol
    static [string] $FavoriteSymbol = [char]0x2605      # ★
    
    # Container Symbol (for multi-repo folders)
    static [string] $ContainerSymbol = "+"              # Simple + for containers
    static [string] $ContainerSymbolAlt = ">"           # Fallback alternative
    
    # UI Colors - Single source of truth for all UI colors
    static [string] $ColorHeader = "Cyan"
    static [string] $ColorSeparator = "Cyan"
    static [string] $ColorMenuText = "Gray"
    static [string] $ColorSelected = "Green"
    static [string] $ColorUnselected = "White"
    static [string] $ColorSelectedBackground = "DarkGray"
    static [string] $ColorFavorite = "Yellow"
    
    # Available background color options for selected items
    static [string[]] $AvailableBackgroundColors = @('None', 'Black', 'DarkGray', 'DarkBlue', 'DarkMagenta', 'DarkCyan', 'DarkGreen', 'DarkRed', 'DarkYellow')
    
    # Available delimiter options for selected items
    static [hashtable[]] $AvailableDelimiters = @(
        @{ Name = 'None'; Left = ''; Right = '' },
        @{ Name = 'Brackets'; Left = '[ '; Right = ' ]' },
        @{ Name = 'Braces'; Left = '{ '; Right = ' }' },
        @{ Name = 'Arrows'; Left = '< '; Right = ' >' },
        @{ Name = 'Double Arrows'; Left = '<< '; Right = ' >>' },
        @{ Name = 'Stars'; Left = '* '; Right = ' *' },
        @{ Name = 'Pipes'; Left = '| '; Right = ' |' }
    )
    
    # Get optimal text color for repository name based on background color
    # Returns the best contrasting color (White or Green) for readability
    static [string] GetTextColorForBackground([string]$backgroundColor) {
        # Default color
        $color = 'Green'
        
        if (-not [string]::IsNullOrWhiteSpace($backgroundColor)) {
            switch ($backgroundColor) {
                'DarkGreen'   { $color = 'White' }   # Verde texto sobre verde fondo = mal contraste
                'DarkRed'     { $color = 'White' }   # Mejor contraste con blanco
                'DarkYellow'  { $color = 'Black' }   # Amarillo oscuro + negro = buen contraste
                'DarkMagenta' { $color = 'White' }   # Magenta + blanco = buen contraste
                'DarkCyan'    { $color = 'White' }   # Cyan + blanco = buen contraste
                'DarkBlue'    { $color = 'White' }   # Azul + blanco = buen contraste
                'DarkGray'    { $color = 'Black' }   # Gris + verde = contraste clásico (tu original)
                'Black'       { $color = 'Green' }   # Negro + verde = buen contraste
                'None'        { $color = 'Green' }   # Sin fondo = verde normal
            }
        }
        
        return $color
    }
    
    static [string] $ColorError = "Red"
    static [string] $ColorSuccess = "Green"
    static [string] $ColorWarning = "Yellow"
    static [string] $ColorInfo = "Gray"
    static [string] $ColorLabel = "Gray"
    static [string] $ColorValue = "White"
    static [string] $ColorHighlight = "Cyan"
    static [string] $ColorPrompt = "Yellow"
    static [string] $ColorHint = "DarkGray"
    
    # Git Status Colors
    static [string] $ColorGitClean = "Green"
    static [string] $ColorGitUncommitted = "Red"
    static [string] $ColorGitUnpushed = "Yellow"
    static [string] $ColorGitUnknown = "DarkGray"
    
    # Repository Status Colors
    static [string] $ColorRepoWithoutModules = "Red"
    
    # Counter Colors
    static [string] $ColorCounterComplete = "Green"
    static [string] $ColorCounterPartial = "Yellow"
    static [string] $ColorCounterEmpty = "Red"
    
    # Initialize configuration from file
    static [void] Initialize([string]$scriptRoot) {
        [Constants]::ScriptRoot = $scriptRoot
        
        $configPath = Join-Path $scriptRoot ".repo-config.json"
        $exampleConfigPath = Join-Path $scriptRoot ".repo-config.example.json"
        
        # Check if config file exists, if not, create from example
        if (-not (Test-Path $configPath)) {
            if (Test-Path $exampleConfigPath) {
                Write-Host "No se encontro el archivo de configuracion .repo-config.json" -ForegroundColor Yellow
                Write-Host "Por favor, copia .repo-config.example.json a .repo-config.json y configura tus rutas" -ForegroundColor Cyan
                Write-Host ""
                Copy-Item $exampleConfigPath $configPath
                Write-Host "Archivo .repo-config.json creado. Editando..." -ForegroundColor Green
                Start-Process notepad $configPath
                Write-Host ""
                Write-Host "Presiona Enter despues de guardar el archivo de configuracion..." -ForegroundColor Yellow
                Read-Host
            } else {
                throw "No se encontro el archivo de configuracion. Debe existir .repo-config.json o .repo-config.example.json"
            }
        }
        
        # Load configuration
        try {
            $config = Get-Content $configPath -Raw | ConvertFrom-Json
            [Constants]::ReposBasePath = $config.reposBasePath
            [Constants]::UserName = $config.userName
        }
        catch {
            throw "Error al cargar la configuracion desde $configPath : $_"
        }
    }
    
    # Methods to get derived values
    static [string] GetAliasFilePath() {
        return Join-Path ([Constants]::ScriptRoot) ([Constants]::AliasFileName)
    }
}

