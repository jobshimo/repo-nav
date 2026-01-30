---
description: Troubleshooting common issues in repo-nav development
---

# Troubleshooting Guide

## Common Issues

### "Unable to find type [ClassName]"

**Cause**: File not imported or imported in wrong order.

**Solutions**:
1. Check file is added to the correct `_index.ps1`
2. Verify import order (dependencies before dependents)
3. Run `.\Build-Bundle.ps1` to check for missing files

### Visual Ghosting/Artifacts

**Cause**: Mixing manual Write-Host with OptionSelector.

**Solution**: Use OptionSelector with `ClearScreen = $true` for all prompts:
```powershell
$config = [SelectionOptions]::new()
$config.ClearScreen = $true
$config.Title = "Title"
# ...
```

### "Method on null-valued expression"

**Cause**: Service not available in context.

**Solution**: Add null guard:
```powershell
if ($null -ne $this.PathManager) {
    $this.PathManager.DoSomething()
} else {
    # Fallback logic
}
```

### State Desync (memory vs file)

**Cause**: Direct manipulation of preferences vs using PathManager.

**Solution**: Always use PathManager for path operations:
```powershell
# ❌ Don't do this
$prefs.repository.defaultPath = $path

# ✅ Do this
$context.PathManager.SetCurrentPath($path)
```

### Bundle Works Different Than Development

**Cause**: File missing from bundle.

**Solution**:
1. Run `.\Build-Bundle.ps1` and check for warnings
2. Verify file is in an `_index.ps1`
3. Check variable resolution in Build-Bundle.ps1

### Array Becomes String (PowerShell quirk)

**Cause**: Single-element arrays become strings in PowerShell.

**Solution**:
```powershell
# ❌ Risky
$paths += $newPath  # String concatenation if $paths is single string!

# ✅ Safe
$pathList = [System.Collections.ArrayList]::new()
foreach ($p in $existingPaths) { [void]$pathList.Add($p) }
[void]$pathList.Add($newPath)
$paths = @($pathList)
```

## Quick Diagnostics

### Check What Files Are Bundled
```powershell
.\Build-Bundle.ps1 | Select-String "discovered"
```

### Test Development Version
```powershell
.\repo-nav.ps1
```

### Test Bundle Version
```powershell
.\dist\repo-nav-bundle.ps1
```

### Validate Project Structure
```powershell
.\scripts\Validate-Project.ps1
```

## Getting Help

1. Check existing similar code in the codebase
2. Review the workflow files in `.agent/workflows/`
3. Ask me (the AI) with context about what you're trying to do
