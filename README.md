# REPO-NAV

> **Navegador interactivo de repositorios en PowerShell con integración de Git, npm y gestión avanzada.**

---

## La Historia

Comencé este proyecto como un simple script de PowerShell para resolver un problema común que tenía: **identificar y navegar rápidamente entre mis múltiples repositorios Git**. Mi idea original era sencilla: quería una forma de asignar alias cortos y coloridos a mis repositorios para reconocerlos instantáneamente.

Lo que empezó como una utilidad de ~200 líneas ha evolucionado hasta convertirse en una aplicación completa, fruto de aplicar mi **mentalidad de ingeniero** y **principios SOLID de ingeniería de software**. A pesar de las limitaciones de PowerShell (sin interfaces reales, POO limitada...), he construido una arquitectura mantenible y extensible siguiendo los **principios SOLID**.

El resultado es lo que ves ahora: una **herramienta CLI de grado profesional** que demuestra cómo un buen diseño puede transformar un script en una aplicación robusta.

**Nota Personal:**
"La excelencia no es un acto, es un hábito. He creado este proyecto como prueba de que no importa el lenguaje; si aplicas buenos principios, puedes crear software de calidad empresarial. PowerShell puede ser mucho más que simples scripts."

---

## Características

### Navegación Principal
- **Navegación con flechas** a través de la lista de repositorios.
- **Soporte jerárquico** — entra y sal de carpetas contenedoras.
- **Paginación inteligente** — se adapta al tamaño de la terminal.
- **Búsqueda en tiempo real** — filtra repositorios mientras escribes (`/` o simplemente escribiendo).
- **Interfaz limpia** — opción para ocultar cabeceras y ganar espacio.

### Gestión de Repositorios
- **Alias personalizados** con colores configurables.
- **Sistema de Favoritos** — fija repos importantes al principio de la lista (`Space` o `F`).
- **Clonar repositorios** directamente desde URLs (`C`).
- **Eliminar repositorios** con confirmaciones de seguridad (`Del`).
- **Crear Carpetas** nuevas para organizar proyectos (`N`).

### Integración con Git (Git Flow)
- **Visualización de Ramas** en tiempo real.
- **Indicadores de Estado** — cambios sin commitear, commits sin pushear.
- **Carga paralela** — carga el estado de todos los repos simultáneamente sin bloquear la UI.
- **Flujo de Integración** (`B` - Flow):
    - Selecciona ramas de origen y destino interactivamente.
    - Chequea estado remoto.
    - Genera URLs de Pull Request automáticamente.

### Integración con npm
- **Instalar dependencias** — ejecuta `npm install` desde el navegador (`I`).
- **Eliminar node_modules** — limpieza rápida con una tecla (`X`).
- **Indicadores visuales** — ve qué repos tienen `node_modules`.

### Experiencia de Usuario (UI/UX)
- **Localización** — Soporte para Inglés y Español.
- **Interfaz Personalizable** (`U` - Preferencias):
    - Colores de selección y fondos.
    - Posición y estilo de los alias.
    - Visibilidad de cabeceras (Modo Compacto).
    - Modos de menú (Completo, Minimalista, Oculto).
- **Diseño visual limpio** — interfaz consistente y legible, respetando el espacio del desarrollador.

---

## Requisitos

| Requisito | Versión | Notas |
|-----------|---------|-------|
| **PowerShell** | 5.1+ | **Requerido** — Usa sintaxis de clases y características modernas |
| **Git** | Cualquiera | *Requerido* para las funcionalidades de control de versiones |
| **npm** | Cualquiera | *Opcional* — Requerido para gestión de paquetes Node.js |

---

## Instalación

### 1. Clonar o Descargar

```powershell
git clone https://github.com/tuusuario/repo-nav.git
cd repo-nav
```

### 2. Ejecutar Setup

```powershell
.\Setup.ps1
```

El asistente de instalación:
- ✓ Verificar requisitos del sistema (PowerShell, Git, npm).
- ✓ Configurará tu ruta base de repositorios.
- ✓ Creará un comando en tu perfil de PowerShell.
- ✓ Creará los archivos de configuración iniciales.

### 3. Recargar Perfil

```powershell
. $PROFILE
```

O reinicia tu terminal.

### 4. Lanzar

```powershell
list
```

(o el nombre del comando que elegiste durante el setup, por defecto `list`, `repo`, o `nav`).

---

## Controles

| Tecla | Acción | Descripción |
|-------|--------|-------------|
| `↑` `↓` | Navegar | Mover selección arriba/abajo |
| `←` `→` | Jerarquía | Entrar/Salir de carpetas contenedoras |
| `Enter` | Abrir | Navegar al repositorio seleccionado en la terminal |
| `Q` / `Esc` | Salir | Salir del navegador |
| `E` | Editar Alias | Establecer o modificar el alias del repositorio |
| `R` | Borrar Alias | Eliminar el alias del repositorio |
| `Espacio` | Favorito | Marcar/Desmarcar como favorito |
| `L` | Cargar Estado | Cargar estado Git del repo actual |
| `G` | Cargar Todo | Cargar estado Git de todos los repos (paralelo) |
| `I` | Instalar | Ejecutar `npm install` |
| `X` | Limpiar | Eliminar carpeta `node_modules` |
| `C` | Clonar | Clonar nuevo repositorio desde URL |
| `N` | Nueva Carpeta | Crear una nueva carpeta |
| `Del` | Eliminar | Eliminar repositorio (con confirmación) |
| `/` | Buscar | Abrir interfaz de búsqueda |
| `U` | Preferencias | Abrir menú de preferencias de usuario |
| `B` | Git Flow | Abrir menú de flujo Git (Integración/PRs) |

---

## Configuración

### Archivos de Setup

| Archivo | Propósito | Estado Git |
|---------|-----------|------------|
| `.repo-config.json` | Tu ruta de repositorios y nombre de usuario | Ignorado |
| `.repo-aliases.json` | Alias de repositorios y favoritos | Ignorado |
| `.repo-preferences.json` | Preferencias de UI y ajustes de usuario | Ignorado |
| `.repo-config.example.json` | Plantilla de configuración | Tracked |

---

## Arquitectura

### Estructura del Proyecto

```
repo-nav/
├── repo-nav.ps1              # Punto de entrada
├── Setup.ps1                 # Asistente de instalación
├── README.md                 # Documentación
├── src/
│   ├── Config/               # Constantes y paletas de colores
│   ├── Models/               # Estructuras de datos (Repository, Alias, GitStatus)
│   ├── Services/             # Capa de Lógica de Negocio (Git, Npm, Alias, Search...)
│   ├── UI/                   # Capa de Presentación (Renderers, Views, Interactive Selectors)
│   └── Core/                 # Núcleo de la aplicación (State, Commands, Factory)
└── tests/                    # Estructura de pruebas (WIP)
```

### Principios de Diseño

Este proyecto sigue **principios SOLID** adaptados para PowerShell:

| Principio | Implementación |
|-----------|----------------|
| **Single Responsibility** | Cada clase tiene un propósito claro y único. |
| **Open/Closed** | Se pueden añadir nuevos comandos sin modificar el código existente. |
| **Liskov Substitution** | Todos los comandos implementan el contrato `INavigationCommand`. |
| **Interface Segregation** | Renderizadores especializados para diferentes componentes UI. |
| **Dependency Inversion** | Servicios inyectados vía constructor, no instanciados internamente. |

### Patrones Clave Usados

- **Command Pattern** — Desacopla la entrada del usuario de la ejecución lógica.
- **Factory Pattern** — `CommandFactory` crea y registra los comandos dinámicamente.
- **State Pattern** — `NavigationState` gestiona todo el estado de navegación de forma centralizada.
- **Facade Pattern** — `RepositoryManager` simplifica operaciones complejas de múltiples servicios.

---

---

## Enfoque de Ingeniería

El objetivo de este proyecto ha sido aplicar buenas prácticas de desarrollo de software para crear una herramienta robusta y mantenible, yendo más allá de un script convencional.

### Aspectos Destacados

1. **Estructura Modular**:
   El código evita el diseño monolítico. Cada funcionalidad está encapsulada en su propia clase y archivo, facilitando el mantenimiento y la lectura.

2. **Inyección de Dependencias**:
   Se utiliza un patrón de inyección de dependencias manual (gestionado en `AppBuilder.ps1`). Los servicios no instancian sus dependencias internamente, lo que reduce el acoplamiento entre componentes.

3. **Claridad del Código (AI Friendly)**:
   El uso de tipado fuerte, nombres descriptivos y contextos claros facilita que tanto humanos como asistentes de IA entiendan la lógica sin ambigüedades.

4. **Optimización**:
   Se implementan estrategias como caché inteligente para el estado de Git y renderizado parcial de la interfaz para asegurar una respuesta rápida y fluida.

---

## Solución de Problemas

### Comando no encontrado tras setup

```powershell
. $PROFILE
```

### Error de ExecutionPolicy

Si PowerShell no te deja ejecutar scripts:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

### Archivo de configuración no encontrado

Ejecuta el setup de nuevo:
```powershell
.\Setup.ps1
```

---

## Privacidad y Seguridad

Este proyecto está diseñado para **nunca exponer información personal**:

- ✓ Tu nombre de usuario NO se sube.
- ✓ Tus rutas de archivos NO se suben.
- ✓ Tus alias y favoritos NO se suben.
- ✓ Todos los archivos de configuración personal están en `.gitignore`.

Solo el código fuente y los archivos de ejemplo se rastrean en Git.

---

## Notas Técnicas

### Limitaciones de PowerShell (Workarounds)

- **Sin interfaces reales** — Usamos clases base abstractas con métodos que lanzan errores.
- **Sin modificadores privados estrictos** — Usamos `hidden` donde es posible.
- **Genéricos limitados** — Trabajamos con `[hashtable]` y `[ArrayList]`.
- **Sin async/await nativo** — Usamos Runspace pools para operaciones paralelas (carga de Git).
- **Orden de carga de clases** — Se requiere una secuencia de carga de archivos cuidadosa en `repo-nav.ps1`.

### Consideraciones de Rendimiento

- **Carga de Git Paralela** — Usa un pool de Runspaces para no congelar la UI.
- **Lazy Loading** — El estado completo de Git se carga bajo demanda o en segundo plano.
- **Renderizado Viewport** — Solo se pintan los elementos visibles en pantalla.
- **Redibujado Optimizado** — Flags de "suciedad" (dirty flags) minimizan parpadeos y actualizaciones de pantalla.

---

## Contribución

Este es mi proyecto personal, pero las sugerencias y pull requests son bienvenidas. El código base demuestra cómo construyo aplicaciones PowerShell mantenibles — siéntete libre de aprender de él o adaptar mis patrones para tus propios proyectos.

---

## Historial de Versiones

| Versión | Descripción |
|---------|-------------|
| **2.1** | **UX Update** — UI Refinament, Preferencias de Cabecera, Git Flow Command, Navegación mejorada. |
| **2.0** | **SOLID Refactor** — Rediseño arquitectónico completo. |
| **1.0** | **Script Original** — Navegación básica y alias. |

---

## Autor

**Martin Miguel Bernal Garcia**  
Enero 2026

---

*Construido con PowerShell, diseñado con principios.*
