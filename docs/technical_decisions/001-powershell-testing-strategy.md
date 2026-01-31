# Registro de Problemas y Estrategia de Testing en PowerShell

**Fecha:** 31 de Enero de 2026
**Estado:** Documento de Referencia / Estrategia Futura

## 1. Resumen de la Situación
Durante el desarrollo de `repo-nav`, nos hemos encontrado con problemas recurrentes y bloqueantes al intentar realizar tests unitarios de las Clases de PowerShell (`class`) utilizando Pester.
El síntoma principal es la aparición de errores `TypeNotFound` (incluso cuando el archivo se carga) y `PSInvalidCastException` (conflictos entre tipos reales y stubs de prueba), lo que ha llevado a una "bola de nieve" de dependencias fallidas.

## 2. Análisis de Causa Raíz

El problema no es la lógica del código, sino las limitaciones arquitectónicas de PowerShell cuando se mezcla con el paradigma de Orientación a Objetos (Clases) en un entorno de scripting interpretado.

### 2.1. "Parse Time" vs "Runtime"
PowerShell intenta resolver **todos** los tipos utilizados en una clase *antes* de ejecutar cualquier línea del script que contiene la clase.
*   **El Problema**: Si `GitFlowCommand.ps1` usa `INavigationCommand`, PowerShell debe conocer `INavigationCommand` *antes* de leer `GitFlowCommand.ps1`. No basta con cargarlo en la línea anterior dentro del script; debe estar en la sesión previamente.
*   **La Trampa**: Si falta una dependencia transitiva (A depende de B, B depende de C, y falta C), PowerShell falla silenciosamente al definir A. El archivo se carga ("Successfully loaded"), pero el tipo A no se crea ("Type NOT FOUND").

### 2.2. Conflicto de Tipos (Inmutabilidad de la Sesión)
En una sesión de PowerShell, **una clase no se puede descargar ni redefinir**.
*   **El Escenario**:
    1.  Test A carga la clase real `UIRenderer`.
    2.  Test B intenta definir una clase falsa `class UIRenderer` para mockearla.
*   **El Error**: PowerShell lanza un error porque `UIRenderer` ya existe. Si intentamos usar herencia o stubs con el mismo nombre, obtenemos `PSInvalidCastException` al intentar pasar un objeto real donde se espera un stub, o viceversa.

## 3. Estrategia de Solución (Roadmap)

Para detener estos problemas y estabilizar la suite de pruebas, adoptaremos la siguiente estrategia basada en **SOLID** y **Clean Code**, adaptada a las limitaciones de PowerShell.

### 3.1. Prohibido Redefinir Clases (No Stubs por Herencia directa)
Jamás definiremos clases "Mock" o "Stub" dentro de los archivos de test que compartan nombre con clases reales o intenten heredar de ellas si la clase real ya está cargada.
*   **Incorrecto**: `class UIRenderer { ... }` en el test.
*   **Correcto**: Usar Interfaces o Mocks Dinámicos.

### 3.2. Uso Obligatorio de Interfaces (Dependency Inversion)
Para que el testing sea posible, las clases no deben depender de otras clases concretas, sino de interfaces.
*   **Acción**: Refactorizar dependencias fuertes.
    *   En lugar de: `[UIRenderer]$renderer`
    *   Usar: `[IUIRenderer]$renderer`
Esto permite que en los tests inyectemos un Mock generado dinámicamente por Pester (`New-MockObject`) sin conflicto de tipos, ya que el Mock implementa la interfaz, no "sobreescribe" la clase.

### 3.3. Gestión Estricta del Gráfico de Dependencias
Debemos mantener un control manual pero estricto del orden de carga en los scripts de test (`BeforeAll`).
*   Orden: Interfaces -> Modelos -> Servicios Base -> Servicios Complejos -> Comandos.
*   Se creará un script o helper de utilidad (`Test-Setup.ps1`) que garantice la carga de *todo* el entorno base antes de correr tests complejos, para evitar el problema de "Parse Time".

### 3.4. Uso de Pester Mocks Dinámicos
Utilizar las capacidades de Pester 5+ para mocking:
```powershell
# En lugar de crear una clase dummy:
$mockRenderer = New-MockObject -Type 'IUIRenderer'
$mockRenderer.MockMethod('RenderMenu', { return 'OpcionSeleccionada' })
```
Esto evita ensuciar la sesión global con tipos conflictivos.

## 4. Estado Actual y Mitigación
Mientras implementamos esta estrategia:
*   Los tests complejos que tienen conflictos de tipos (ej. `GitFlowCommand.Tests.ps1`) se mantienen en estado **Skipped** para no bloquear el CI/CD.
*   Se prioriza la cobertura de Servicios y Utilidades que no tienen dependencias cruzadas complejas.
*   Las nuevas funcionalidades deben nacer con Interfaces (`I...`) desde el principio.
