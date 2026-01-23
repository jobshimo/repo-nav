<#
.SYNOPSIS
    Constants class - Single source of truth for all application constants
    
.DESCRIPTION
    Following SRP (Single Responsibility Principle):
    This class only holds constants and provides static access to them.
#>

class Constants {
    # Paths
    static [string] $ReposBasePath = "C:\Users\X518795\repos"
    static [string] $AliasFileName = ".repo-aliases.json"
    
    # Virtual Key Codes
    static [int] $KEY_UP_ARROW = 38
    static [int] $KEY_DOWN_ARROW = 40
    static [int] $KEY_ENTER = 13
    static [int] $KEY_E = 69
    static [int] $KEY_R = 82
    static [int] $KEY_Q = 81
    static [int] $KEY_ESC = 27
    static [int] $KEY_I = 73
    static [int] $KEY_X = 88
    static [int] $KEY_DELETE = 46
    static [int] $KEY_C = 67
    static [int] $KEY_G = 71
    static [int] $KEY_L = 76
    static [int] $KEY_F = 70
    
    # UI Constants
    static [int] $CursorStartLine = 10
    
    # Git Status Symbols
    static [string] $GitSymbolClean = [char]0x2713      # ✓
    static [string] $GitSymbolUncommitted = [char]0x25CF # ●
    static [string] $GitSymbolUnpushed = [char]0x2191    # ↑
    static [string] $GitSymbolUnknown = "?"
    
    # Favorite Symbol
    static [string] $FavoriteSymbol = [char]0x2605      # ★
    
    # Methods to get derived values
    static [string] GetAliasFilePath() {
        return "C:\Users\X518795\repos\repo-nav\.repo-aliases.json"
    }
}

