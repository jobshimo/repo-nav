# REPO-NAV

> **Mi navegador de repositorios en PowerShell** — gestión de Git, npm y organización de proyectos desde la terminal.

![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue?logo=powershell)
![License](https://img.shields.io/badge/License-MIT-green)
![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey)

---

## ¿Por Qué Hice Esto?

Tengo muchos repositorios. Demasiados, probablemente. Y me cansé de hacer `cd ../otro-proyecto` veinte veces al día, de olvidar en qué rama estaba cada repo, y de tener que abrir el explorador para recordar si ya había borrado los `node_modules` de ese proyecto que no toco hace meses.

Empecé con un script de 200 líneas que simplemente listaba carpetas. Pero me enganchó. Quería alias con colores para identificar los repos al vuelo. Quería ver el estado de Git sin ejecutar comandos. Quería que fuera rápido.

Lo que comenzó como una herramienta práctica se convirtió en un proyecto donde apliqué todo lo que sabía sobre arquitectura de software. PowerShell no es el lenguaje más cómodo para hacer OOP, pero eso fue parte del reto. Cada problema que encontré me obligó a buscar soluciones creativas, y eso es lo que más disfruté.

**El resultado**: una aplicación que uso todos los días en mi trabajo y que espero te sea útil a ti también.

---

## ¿Qué Hace?

### 📂 Navegación Inteligente
- **Lista interactiva** de todos mis repositorios con navegación por teclado
- **Jerarquía de carpetas**: entro y salgo de carpetas contenedoras
- **Búsqueda instantánea**: escribo directamente o pulso `/` para filtrar
- **Paginación automática**: se adapta al tamaño de la terminal
- **Favoritos**: los repos que más uso aparecen primero

### � Personalización Visual
- **Alias con colores**: identifico cada repo de un vistazo (Angular = rojo, APIs = verde, etc.)
- **Temas**: colores de selección, fondo, estilo de alias
- **Modos de menú**: Completo, Minimalista u Oculto
- **Modo compacto**: oculta cabeceras para ver más repos
- **Idiomas**: Español e Inglés

### 🔀 Integración Profunda con Git
- **Rama actual** visible en cada repositorio
- **Indicadores de estado**: cambios sin commit (●) y commits sin push (↑)
- **Carga paralela**: consulta el estado de Git de todos los repos sin bloquear la UI
- **Flujo de Integración**: selecciono rama origen → rama destino → me genera la URL del Pull Request
- **Quick Changes**: workflow rápido para cambios pequeños

### 📦 Gestión de npm
- **npm install** con una tecla (`I`)
- **Borrar node_modules** de cualquier repo (`X`)
- Indicador visual de qué repos tienen `node_modules`

### 🛠️ Herramientas de Organización
- **Clonar repos** pegando la URL de GitHub
- **Crear carpetas** para organizar proyectos
- **Eliminar repos** (con confirmación de seguridad)

---

## Lo Que Más Disfruté Creando Esto

### El Reto de PowerShell + OOP
PowerShell no está diseñado para aplicaciones grandes. No tiene interfaces reales, la herencia es limitada, y la comunidad no tiene muchos ejemplos de arquitecturas complejas. Pero eso me obligó a ser creativo.

Implementé un sistema de **inyección de dependencias manual** que funciona sorprendentemente bien. Cada comando sigue el **patrón Command**, lo que hace muy fácil añadir nuevas funcionalidades sin tocar el código existente. Y el **patrón Factory** me permitió separar la lógica de qué tecla hace qué.

### El Sistema de Renderizado
La terminal es un medio limitado. No puedo simplemente "repintar un componente" como en una UI web. Tuve que implementar un sistema de **dirty flags** que detecta qué partes de la pantalla cambiaron y solo repinta esas. El resultado es una interfaz fluida que no parpadea.

### La Carga Paralela de Git
Consultar el estado de Git de 50 repositorios puede tardar segundos. Para no congelar la interfaz, implementé un **pool de Runspaces** que lanza las consultas en paralelo y actualiza la UI conforme llegan los resultados. La primera vez que lo vi funcionando fue muy satisfactorio.

### El Sistema de Bundling
Para distribución creé un sistema que concatena los ~70 archivos fuente en uno solo. Esto reduce el tiempo de carga un 60% y hace el deploy trivial: un único archivo `.ps1`. El build además transforma las rutas automáticamente, manteniendo el código de desarrollo limpio.

---

## Requisitos

| Requisito | Versión | Notas |
|-----------|---------|-------|
| **PowerShell** | 5.1+ | Necesario (usa clases y características modernas) |
| **Git** | Cualquiera | Para las funciones de control de versiones |
| **npm** | Cualquiera | *Opcional* — solo si gestionas proyectos Node.js |

---

## Instalación

### Opción A: Desarrollo (código fuente completo)

```powershell
git clone https://github.com/tuusuario/repo-nav.git
cd repo-nav
.\Setup.ps1
```

### Opción B: Bundle (archivo único, más rápido)

```powershell
# Generar el bundle
.\Build-Bundle.ps1

# O con minificación (25% más pequeño)
.\Build-Bundle.ps1 -Minify
```

La carpeta `dist/` contendrá:
- `Install.bat` — Ejecutar primero (configura PowerShell automáticamente)
- `repo-nav-bundle.ps1` — La aplicación
- `Setup-Bundle.ps1` — Asistente de configuración
- `Resources/` — Traducciones

**Para instalar en otro equipo:**
1. Copia la carpeta `dist/` al equipo destino
2. Haz doble clic en `Install.bat`

> **Nota**: Si Windows bloquea la ejecución de scripts .ps1, el Install.bat lo soluciona automáticamente configurando las políticas de ejecución.

El asistente de Setup:
- Verifica que tengas PowerShell, Git y npm
- Te pide la ruta donde guardas tus repositorios
- Crea un comando en tu perfil de PowerShell
- Genera los archivos de configuración

### Recargar el Perfil

```powershell
. $PROFILE
```

O simplemente reinicia la terminal.

### Lanzar

```powershell
list
```

(O el nombre que hayas elegido durante el setup: `repo`, `nav`, `r`, etc.)

---

## Controles

| Tecla | Acción |
|-------|--------|
| `↑` `↓` | Mover selección |
| `←` `→` | Entrar/salir de carpetas |
| `Enter` | Abrir repo en terminal |
| `Q` / `Esc` | Salir |
| `E` | Editar alias |
| `R` | Borrar alias |
| `Espacio` | Marcar favorito |
| `L` | Cargar estado Git del repo actual |
| `G` | Cargar estado Git de todos los repos |
| `I` | npm install |
| `X` | Borrar node_modules |
| `C` | Clonar repo |
| `N` | Nueva carpeta |
| `Del` | Eliminar repo |
| `/` | Buscar |
| `U` | Preferencias |
| `B` | Flujo Git (integración/PRs) |

---

## Arquitectura

```
repo-nav/
├── repo-nav.ps1              # Punto de entrada (desarrollo)
├── Build-Bundle.ps1          # Genera el bundle para distribución
├── Setup.ps1                 # Instalador
├── src/
│   ├── Config/               # Constantes y paleta de colores
│   ├── Models/               # Modelos de datos
│   ├── Services/             # Lógica de negocio (Git, npm, búsqueda...)
│   ├── UI/                   # Interfaz (renderers, vistas, selectores)
│   ├── Core/                 # Motor (estado, comandos, flujos)
│   ├── Startup/              # Inyección de dependencias
│   └── Resources/i18n/       # Traducciones (en.json, es.json)
└── dist/                     # Salida del build (gitignored)
    ├── repo-nav-bundle.ps1
    ├── Setup-Bundle.ps1
    └── Resources/i18n/
```

### Principios Aplicados

- **SOLID**: Cada clase tiene una responsabilidad clara
- **Command Pattern**: Cada acción es un comando independiente
- **Factory Pattern**: Mapeo de teclas a comandos
- **Inyección de dependencias**: Gestionada en `AppBuilder.ps1`
- **Sistema de índices por capas**: Imports organizados por dependencias

### Optimizaciones de Rendimiento

- **Git en paralelo**: Pool de Runspaces para no congelar la UI
- **Lazy loading**: Solo cargo el estado Git cuando lo necesito
- **Renderizado parcial**: Solo repinto lo que cambia
- **Bundling**: 60% más rápido al eliminar I/O de 70+ archivos

---

## Configuración

| Archivo | Para qué sirve | ¿Se sube a Git? |
|---------|----------------|-----------------|
| `.repo-aliases.json` | Tus alias y favoritos | No |
| `.repo-preferences.json` | Preferencias de interfaz y ruta por defecto | No |
| `dist/` | Bundle generado | No |

---

## Solución de Problemas

**El comando no funciona tras el setup:**
```powershell
. $PROFILE
```

**PowerShell no me deja ejecutar scripts:**
```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

**Regenerar el bundle tras cambios:**
```powershell
.\Build-Bundle.ps1
```

---

## Historial

| Versión | Cambios |
|---------|---------|
| **2.2** | Sistema de bundling para distribución, optimización 60% más rápido |
| **2.1** | Git Flow, preferencias de UI, navegación mejorada |
| **2.0** | Rediseño completo con principios SOLID |
| **1.0** | Script original con navegación y alias |

---

## Autor

**Martin Miguel Bernal Garcia**  
Enero 2026

---

*Hecho en PowerShell para quienes vivimos en la terminal. Si te resulta útil, dame una estrella ⭐*
