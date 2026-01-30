---
description: How to add a new UI component to repo-nav
---

# Adding a New UI Component

## Component Types

1. **View** - Full screen display (e.g., SearchView, AliasView)
2. **Component** - Reusable UI element (e.g., OptionSelector, ColorSelector)
3. **Controller** - Complex UI with state (e.g., PreferencesMenuController)

## Steps for Adding a View

### 1. Create the View File

Create `src/UI/Views/YourView.ps1`:

```powershell
class YourView {
    [ConsoleHelper] $Console
    [UIRenderer] $Renderer
    [LocalizationService] $Loc
    
    YourView([ConsoleHelper]$console, [UIRenderer]$renderer, [LocalizationService]$loc) {
        $this.Console = $console
        $this.Renderer = $renderer
        $this.Loc = $loc
    }
    
    [object] Show([object]$data) {
        try {
            $this.Console.HideCursor()
            $this.Console.ClearScreen()
            
            # Render header
            $this.Renderer.RenderHeader($this.Loc.Get("YourView.Title"))
            
            # Your UI logic here
            
            return $result
        }
        finally {
            $this.Console.ShowCursor()
        }
    }
}
```

### 2. Add to UI _index.ps1

Edit `src/UI/_index.ps1` and add:

```powershell
. "$uiPath\Views\YourView.ps1"
```

### 3. Use from Command/Controller

```powershell
$view = [YourView]::new($context.Console, $context.Renderer, $context.LocalizationService)
$result = $view.Show($data)
```

## Steps for Adding a Reusable Component

### 1. Create Component File

Create `src/UI/Components/YourComponent.ps1`:

```powershell
class YourComponent {
    [ConsoleHelper] $Console
    
    YourComponent([ConsoleHelper]$console) {
        $this.Console = $console
    }
    
    [void] Render([object]$options) {
        # Rendering logic
    }
}
```

### 2. Add to UI _index.ps1

Must be added BEFORE views that use it.

## Best Practices

### Always Use Localization
```powershell
# ❌ Bad
$this.Renderer.RenderHeader("My Title")

# ✅ Good
$this.Renderer.RenderHeader($this.Loc.Get("MyView.Title"))
```

### Handle Cursor State
```powershell
try {
    $this.Console.HideCursor()
    # ... interactive UI
}
finally {
    $this.Console.ShowCursor()  # Always restore!
}
```

### Clear Screen Before Full Views
```powershell
$this.Console.ClearScreen()
```

### Use OptionSelector for Lists
Don't reinvent the wheel - use existing components.

## Verification

// turbo
1. Run `.\repo-nav.ps1` to test visually
2. Run `.\Build-Bundle.ps1` to verify bundle builds
3. Test with different terminal sizes
