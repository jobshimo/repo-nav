<#
.SYNOPSIS
    IArrayHelper - Interface for array utility operations
    
.DESCRIPTION
    Abstraction for safe array operations following DIP.
    Static methods pattern for utility operations.
#>

class IArrayHelper {
    # Ensures a value is always returned as an array
    static [array] EnsureArray([object]$value) {
        throw "Not Implemented: EnsureArray must be overridden"
    }
    
    # Safely append an item to an array
    static [array] SafeAppend([array]$existingArray, [object]$newItem) {
        throw "Not Implemented: SafeAppend must be overridden"
    }
    
    # Safely remove an item from an array
    static [array] SafeRemove([array]$existingArray, [object]$itemToRemove) {
        throw "Not Implemented: SafeRemove must be overridden"
    }
}
