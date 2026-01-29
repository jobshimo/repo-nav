class ServiceRegistry {
    static [hashtable] $Services = @{}
    
    # Register a service instance by type name or custom key
    static [void] Register([string]$key, [object]$service) {
        if ([ServiceRegistry]::Services.ContainsKey($key)) {
            [ServiceRegistry]::Services[$key] = $service
        } else {
            [ServiceRegistry]::Services.Add($key, $service)
        }
    }
    
    # Resolve a service by key
    static [object] Resolve([string]$key) {
        if ([ServiceRegistry]::Services.ContainsKey($key)) {
            return [ServiceRegistry]::Services[$key]
        }
        return $null
    }
    
    # Resolve typed (helper)
    static [object] Resolve([type]$type) {
        return [ServiceRegistry]::Resolve($type.Name)
    }

    # Clear all services (for testing/reset)
    static [void] Reset() {
        [ServiceRegistry]::Services.Clear()
    }
}
