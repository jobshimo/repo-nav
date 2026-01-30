<#
.SYNOPSIS
    ArrayHelper - Utilities for safe array operations in PowerShell.
    
.DESCRIPTION
    PowerShell has a quirk where single-element arrays become strings.
    This causes bugs like string concatenation instead of array append.
    
    This helper provides safe array operations to prevent these issues.
    
    Following SOLID principles:
    - SRP: Only handles array utility operations
#>

class ArrayHelper {
    <#
    .SYNOPSIS
        Ensures a value is always returned as an array.
        
    .DESCRIPTION
        Handles PowerShell's quirk where single-element arrays become strings.
        - null → empty array
        - string → single-element array
        - array → array (filtered for nulls)
        
    .EXAMPLE
        $paths = [ArrayHelper]::EnsureArray($preferences.repository.paths)
    #>
    static [array] EnsureArray([object]$value) {
        if ($null -eq $value) {
            return @()
        }
        
        if ($value -is [string]) {
            # Single string - wrap in array
            if ([string]::IsNullOrWhiteSpace($value)) {
                return @()
            }
            return @($value)
        }
        
        if ($value -is [array]) {
            # Filter nulls and empty strings
            return @($value | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        }
        
        # Other types - wrap in array
        return @($value)
    }
    
    <#
    .SYNOPSIS
        Safely adds an item to an array without string concatenation.
        
    .EXAMPLE
        $newArray = [ArrayHelper]::AddToArray($existingArray, $newItem)
    #>
    static [array] AddToArray([object]$existingArray, [object]$newItem) {
        $list = [System.Collections.ArrayList]::new()
        
        $normalized = [ArrayHelper]::EnsureArray($existingArray)
        foreach ($item in $normalized) {
            [void]$list.Add($item)
        }
        
        if ($null -ne $newItem -and -not [string]::IsNullOrWhiteSpace($newItem)) {
            [void]$list.Add($newItem)
        }
        
        return @($list)
    }
    
    <#
    .SYNOPSIS
        Safely removes an item from an array.
        
    .EXAMPLE
        $newArray = [ArrayHelper]::RemoveFromArray($existingArray, $itemToRemove)
    #>
    static [array] RemoveFromArray([object]$existingArray, [object]$itemToRemove) {
        $normalized = [ArrayHelper]::EnsureArray($existingArray)
        return @($normalized | Where-Object { $_ -ne $itemToRemove })
    }
    
    <#
    .SYNOPSIS
        Checks if an array contains an item (case-insensitive for strings).
        
    .EXAMPLE
        if ([ArrayHelper]::Contains($paths, $newPath)) { ... }
    #>
    static [bool] Contains([object]$existingArray, [object]$item) {
        $normalized = [ArrayHelper]::EnsureArray($existingArray)
        return $normalized -contains $item
    }
}
