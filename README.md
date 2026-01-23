# 📁 Repository Navigator# 📁 Repository Navigator



> **Una herramienta interactiva en PowerShell para gestionar múltiples repositorios Git con aliases, operaciones npm y seguimiento de estado.**> **Una herramienta interactiva en PowerShell para gestionar múltiples repositorios Git con aliases, operaciones npm y seguimiento de estado.**



[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://github.com/PowerShell/PowerShell)[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://github.com/PowerShell/PowerShell)

[![License](https://img.shields.io/badge/License-Internal-red.svg)](LICENSE)[![License](https://img.shields.io/badge/License-Internal-red.svg)](LICENSE)

![Status](https://img.shields.io/badge/Status-Active-success)

![Demo Preview](https://img.shields.io/badge/Status-Active-success)

---

---

## 📖 Tabla de Contenidos

## 📖 Tabla de Contenidos

- [¿Qué es esto?](#-qué-es-esto)

- [Instalación](#-instalación)- [¿Qué es esto?](#-qué-es-esto)

- [Uso Rápido](#-uso-rápido)- [Instalación](#-instalación)

- [Controles](#-controles)- [Uso Rápido](#-uso-rápido)

- [Características](#-características)- [Controles](#-controles)

- [Configuración](#-configuración)- [Características](#-características)

- [Estructura del Proyecto](#-estructura-del-proyecto)- [Configuración](#-configuración)

- [Troubleshooting](#-troubleshooting)- [Estructura del Proyecto](#-estructura-del-proyecto)

- [Troubleshooting](#-troubleshooting)

---

---

## 🎯 ¿Qué es esto?

## 🎯 ¿Qué es esto?

**Repository Navigator** es una interfaz de terminal interactiva que te permite:

**Repository Navigator** es una interfaz de terminal interactiva que te permite:

- 📂 Navegar rápidamente entre todos tus repositorios

- 🏷️ Crear **aliases con colores** para identificar proyectos importantes- 📂 Navegar rápidamente entre todos tus repositorios

- 📊 Ver el **estado de Git** (branch, commits pendientes, cambios)- 🏷️ Crear **aliases con colores** para identificar proyectos importantes

- 📦 Gestionar **node_modules** (instalar/eliminar)- 📊 Ver el **estado de Git** (branch, commits pendientes, cambios)

- 🔄 **Clonar** nuevos repositorios- 📦 Gestionar **node_modules** (instalar/eliminar)

- 🗑️ Eliminar repositorios con confirmación de seguridad- 🔄 **Clonar** nuevos repositorios

- 🗑️ Eliminar repositorios con confirmación de seguridad

---

---

## 🚀 Instalación

## 🚀 Instalación

### Requisitos

### Requisitos

- **PowerShell 5.1+** (viene con Windows)

- **Git** instalado- **PowerShell 5.1+** (viene con Windows)

- **npm** (opcional, solo si trabajas con proyectos Node.js)- **Git** instalado

- **npm** (opcional, solo si trabajas con proyectos Node.js)

### Pasos

### Pasos

**1️⃣ Clona o descarga este repositorio**

1️⃣ **Clona o descarga este repositorio**

```powershell

git clone https://github.com/jobshimo/repo-nav.git```powershell

cd repo-navgit clone https://github.com/jobshimo/repo-nav.git

```cd repo-nav

```

**2️⃣ Ejecuta el instalador interactivo**

2️⃣ **Ejecuta el instalador interactivo**

```powershell

.\Install.ps1```powershell

```.\Install.ps1

```

**3️⃣ Sigue las instrucciones**

3️⃣ **Sigue las instrucciones**

El instalador te preguntará:

- 📁 **Ruta de tus repositorios** (ej: `C:\Users\TuUsuario\repos`)El instalador te preguntará:

- 🔤 **Nombre del comando** (por defecto: `list`, pero puedes usar `repos`, `nav`, etc.)- 📁 **Ruta de tus repositorios** (ej: `C:\Users\TuUsuario\repos`)

- 🔤 **Nombre del comando** (por defecto: `list`, pero puedes usar `repos`, `nav`, etc.)

**4️⃣ Recarga tu perfil de PowerShell**

4️⃣ **Recarga tu perfil de PowerShell**

```powershell

. $PROFILE```powershell

```. $PROFILE

```

**5️⃣ ¡Listo! Ejecuta el comando**

5️⃣ **¡Listo! Ejecuta el comando**

```powershell

list  # o el nombre que hayas elegido```powershell

```list  # o el nombre que hayas elegido

```

---

---

## 💡 Uso Rápido

## 💡 Uso Rápido

Simplemente escribe el comando que configuraste (por defecto `list`) y navega con las flechas del teclado:

Simplemente escribe el comando que configuraste (por defecto `list`) y navega con las flechas del teclado:

```powershell

list```powershell

```list

```

**Acciones disponibles:**

![Navigation Example](https://img.shields.io/badge/Example-Interactive%20UI-informational)

- 🔼🔽 Navega con las flechas

- ⏎ Presiona `Enter` para abrir el repositorio en esa ubicación

- 🏷️ Presiona `E` para asignar un alias con color**Acciones disponibles:**

- 🔄 Presiona `G` para cargar el estado de Git de todos los repos

- 🔼🔽 Navega con las flechas

---- ⏎ Presiona `Enter` para abrir el repositorio en esa ubicación

- 🏷️ Presiona `E` para asignar un alias con color

## ⌨️ Controles- 🔄 Presiona `G` para cargar el estado de Git de todos los repos



| Tecla | Acción | Descripción |---

|:-----:|:-------|:------------|

| <kbd>↑</kbd> <kbd>↓</kbd> | **Navegar** | Muévete entre repositorios |## ⌨️ Controles

| <kbd>Enter</kbd> | **Abrir** | Abre el repositorio seleccionado (cambia el directorio) |

| <kbd>E</kbd> | **Editar Alias** | Crea o modifica el alias del repositorio || Tecla | Acción | Descripción |

| <kbd>R</kbd> | **Remover Alias** | Elimina el alias del repositorio ||:-----:|:-------|:------------|

| <kbd>I</kbd> | **Install** | Ejecuta `npm install` en el repositorio || <kbd>↑</kbd> <kbd>↓</kbd> | **Navegar** | Muévete entre repositorios |

| <kbd>X</kbd> | **Remove** | Elimina la carpeta `node_modules` || <kbd>Enter</kbd> | **Abrir** | Abre el repositorio seleccionado (cambia el directorio) |

| <kbd>C</kbd> | **Clone** | Clona un nuevo repositorio desde URL || <kbd>E</kbd> | **Editar Alias** | Crea o modifica el alias del repositorio |

| <kbd>Del</kbd> | **Delete** | Elimina el repositorio (con confirmación) || <kbd>R</kbd> | **Remover Alias** | Elimina el alias del repositorio |

| <kbd>L</kbd> | **Load Status** | Carga el estado de Git del repo actual || <kbd>I</kbd> | **Install** | Ejecuta `npm install` en el repositorio |

| <kbd>G</kbd> | **Load All** | Carga el estado de Git de **todos** los repos || <kbd>X</kbd> | **Remove** | Elimina la carpeta `node_modules` |

| <kbd>Q</kbd> / <kbd>Esc</kbd> | **Salir** | Cierra el navegador || <kbd>C</kbd> | **Clone** | Clona un nuevo repositorio desde URL |

| <kbd>Del</kbd> | **Delete** | Elimina el repositorio (con confirmación) |

---| <kbd>L</kbd> | **Load Status** | Carga el estado de Git del repo actual |

| <kbd>G</kbd> | **Load All** | Carga el estado de Git de **todos** los repos |

## ✨ Características| <kbd>Q</kbd> / <kbd>Esc</kbd> | **Salir** | Cierra el navegador |



### 🏷️ Sistema de Aliases---



Asigna **nombres cortos y colores** a tus repositorios favoritos:## ✨ Características



```json### 🏷️ Sistema de Aliases

{

  "mi-proyecto-largo-nombre": {Asigna **nombres cortos y colores** a tus repositorios favoritos:

    "alias": "MPN",

    "color": "Green",```json

    "isFavorite": true{

  }  "mi-proyecto-largo-nombre": {

}    "alias": "MPN",

```    "color": "Green",

    "isFavorite": true

- Los repositorios con alias aparecen **primero** en la lista  }

- **14 colores disponibles** para categorizar proyectos}

- Fácil identificación visual```



### 📊 Estado de Git- Los repositorios con alias aparecen **primero** en la lista

- **14 colores disponibles** para categorizar proyectos

Visualiza el estado de cada repositorio:- Fácil identificación visual



- 🌿 **Branch actual**### 📊 Estado de Git

- ⬆️ **Commits por enviar** (ahead)

- ⬇️ **Commits por recibir** (behind)Visualiza el estado de cada repositorio:

- 📝 **Cambios sin commitear**

- 🌿 **Branch actual**

### 📦 Gestión de npm- ⬆️ **Commits por enviar** (ahead)

- ⬇️ **Commits por recibir** (behind)

- **Instalar dependencias** con `npm install`- 📝 **Cambios sin commitear**

- **Eliminar node_modules** para liberar espacio

- Operaciones interactivas con confirmación### 📦 Gestión de npm



### 🗂️ Organización Inteligente- **Instalar dependencias** con `npm install`

- **Eliminar node_modules** para liberar espacio

- Repositorios **favoritos primero**- Operaciones interactivas con confirmación

- Orden **alfabético** automático

- Búsqueda visual rápida### 🗂️ Organización Inteligente



---- Repositorios **favoritos primero**

- Orden **alfabético** automático

## ⚙️ Configuración- Búsqueda visual rápida



### 📁 Ubicación de Archivos---



Después de la instalación:## ⚙️ Configuración



```### 📁 Ubicación de Archivos

repo-nav/

├── .repo-aliases.json        # ← Aliases guardados aquíDespués de la instalación:

├── src/Config/Constants.ps1  # ← Ruta de tus repositorios

└── ...```

```repo-nav/

├── .repo-aliases.json        # ← Aliases guardados aquí

### 🔧 Cambiar la Ruta de Repositorios├── src/Config/Constants.ps1  # ← Ruta de tus repositorios

└── ...

**Opción 1:** Vuelve a ejecutar el instalador```



```powershell### 🔧 Cambiar la Ruta de Repositorios

.\Install.ps1

```**Opción 1:** Vuelve a ejecutar el instalador



**Opción 2:** Edita manualmente `src/Config/Constants.ps1````powershell

.\Install.ps1

```powershell```

static [string] $ReposBasePath = "C:\Tu\Nueva\Ruta"

```**Opción 2:** Edita manualmente `src/Config/Constants.ps1`



### 🎨 Colores Disponibles```powershell

static [string] $ReposBasePath = "C:\Tu\Nueva\Ruta"

| Color | Variante Oscura |```

|-------|----------------|

| `Yellow` | `DarkYellow` |### 🎨 Colores Disponibles

| `Green` | `DarkGreen` |

| `Cyan` | `DarkCyan` || Color | Variante Oscura |

| `Magenta` | `DarkMagenta` ||-------|----------------|

| `Blue` | `DarkBlue` || `Yellow` | `DarkYellow` |

| `Red` | `DarkRed` || `Green` | `DarkGreen` |

| `White` | `Gray` || `Cyan` | `DarkCyan` |

| `Magenta` | `DarkMagenta` |

### 📝 Formato del Archivo de Aliases| `Blue` | `DarkBlue` |

| `Red` | `DarkRed` |

El archivo `.repo-aliases.json` tiene esta estructura:| `White` | `Gray` |



```json### � Formato del Archivo de Aliases

{

  "nombre-del-repositorio": {El archivo `.repo-aliases.json` tiene esta estructura:

    "alias": "ALIAS-CORTO",

    "color": "Green",```json

    "isFavorite": true{

  },  "nombre-del-repositorio": {

  "otro-repositorio": {    "alias": "ALIAS-CORTO",

    "alias": "OTRO",    "color": "Green",

    "color": "Cyan",    "isFavorite": true

    "isFavorite": true  },

  }  "otro-repositorio": {

}    "alias": "OTRO",

```    "color": "Cyan",

    "isFavorite": true

---  }

}

## 📂 Estructura del Proyecto```



El proyecto está organizado siguiendo **principios SOLID** y **patrones de diseño OOP**:---



```## 📂 Estructura del Proyecto

repo-nav/

│```

├── 📄 repo-nav.ps1                # Punto de entrada principalrepo-nav/

├── 📄 Install.ps1                 # Script de instalación├── repo-nav.ps1          # Main entry point

├── 📄 README.md                   # Esta documentación├── Install.ps1           # Installation script

├── 📄 .repo-aliases.json          # Aliases guardados├── README.md             # This file

│└── src/                  # Source code

└── 📁 src/    ├── Config/           # Configuration & constants

    │    │   ├── Constants.ps1

    ├── 📁 Config/                 # ⚙️ Configuración    │   └── ColorPalette.ps1

    │   ├── Constants.ps1          #    Rutas y constantes    ├── Models/           # Data models (DTOs)

    │   └── ColorPalette.ps1       #    Paleta de colores    │   ├── AliasInfo.ps1

    │    │   ├── GitStatusModel.ps1

    ├── 📁 Models/                 # 📦 Modelos de datos    │   └── RepositoryModel.ps1

    │   ├── AliasInfo.ps1          #    Información de alias    ├── Services/         # Business logic

    │   ├── GitStatusModel.ps1     #    Estado de Git    │   ├── AliasManager.ps1

    │   └── RepositoryModel.ps1    #    Modelo de repositorio    │   ├── ConfigurationService.ps1

    │    │   ├── GitService.ps1

    ├── 📁 Services/               # 🔧 Lógica de negocio    │   ├── InteractiveHelpers.ps1

    │   ├── AliasManager.ps1       #    Gestión de aliases    │   ├── NpmHelpers.ps1

    │   ├── ConfigurationService.ps1 #  Configuración    │   └── NpmService.ps1

    │   ├── GitService.ps1         #    Operaciones Git    ├── UI/               # User interface

    │   ├── InteractiveHelpers.ps1 #    Helpers interactivos    │   ├── ColorSelector.ps1

    │   ├── NpmHelpers.ps1         #    Helpers npm    │   ├── ConsoleHelper.ps1

    │   └── NpmService.ps1         #    Servicio npm    │   └── UIRenderer.ps1

    │    └── Core/             # Application core

    ├── 📁 UI/                     # 🎨 Interfaz de usuario        ├── NavigationLoop.ps1

    │   ├── ColorSelector.ps1      #    Selector de colores        └── RepositoryManager.ps1

    │   ├── ConsoleHelper.ps1      #    Utilidades de consola```

    │   └── UIRenderer.ps1         #    Renderizado UI

    │## 🏗️ Architecture

    └── 📁 Core/                   # 🧠 Núcleo de la aplicación

        ├── NavigationLoop.ps1     #    Loop de navegaciónBuilt using **SOLID principles** and **OOP design patterns**:

        ├── NavigatorController.ps1 #   Controlador principal

        └── RepositoryManager.ps1  #    Manager de repositorios- **Single Responsibility**: Each class has one clear purpose

```- **Open/Closed**: Easy to extend without modifying existing code

- **Dependency Injection**: All dependencies injected through constructors

### 🏗️ Arquitectura- **Facade Pattern**: `RepositoryManager` provides high-level operations

- **Separation of Concerns**: Models, Services, UI, and Core layers

- **Single Responsibility**: Cada clase tiene un propósito único y claro

- **Open/Closed**: Fácil de extender sin modificar código existente## 🔧 Configuration

- **Dependency Injection**: Dependencias inyectadas vía constructores

- **Facade Pattern**: `RepositoryManager` proporciona operaciones de alto nivel### Aliases Storage

- **Separation of Concerns**: Capas separadas (Models, Services, UI, Core)

Aliases are now stored **inside the app folder**:

---- **Location**: `repo-nav/.repo-aliases.json`

- **Benefit**: Keeps your repos folder clean

## 🐛 Troubleshooting- **Migration**: Installer automatically moves existing file



### ❌ "El comando no se reconoce"### File Format



**Solución:** Recarga tu perfil de PowerShell```json

{

```powershell  "cib-dpemp-lrclntrequestngn": {

. $PROFILE    "alias": "CRE",

```    "color": "Green",

    "isFavorite": true

### ❌ "No se puede ejecutar el script (ExecutionPolicy)"  },

  "cib-dpemp-crebulk": {

**Solución:** Cambia la política de ejecución    "alias": "CRE-BULK",

    "color": "Yellow",

```powershell    "isFavorite": true

Set-ExecutionPolicy -Scope CurrentUser RemoteSigned  }

```}

```

Luego confirma con `Y` (Yes).

### Customizing Paths

### ❌ "Los repositorios no se encuentran"

If you need to change paths after installation, you can:

**Solución 1:** Re-ejecuta el instalador

1. **Re-run the installer**: `.\Install.ps1` (will update everything)

```powershell2. **Manual edit**: Modify `src/Config/Constants.ps1`:

.\Install.ps1   ```powershell

```   static [string] $ReposBasePath = "C:\Your\Repos\Path"

   ```

**Solución 2:** Edita manualmente tu `$PROFILE`

## 🎨 Available Colors

```powershell

notepad $PROFILEYellow, Green, Cyan, Magenta, Blue, Red, DarkYellow, DarkGreen, DarkCyan, DarkMagenta, DarkBlue, DarkRed, White, Gray

```

## 📋 Requirements

Busca la función del comando (ej: `list`) y actualiza la ruta.

- **PowerShell 5.1+**

### ❌ "El archivo de aliases no existe"- **Git** (for Git operations)

- **npm** (for node_modules management)

No te preocupes, se creará automáticamente al asignar tu primer alias.

## 🔄 Updating

### ℹ️ Ver la ubicación de tu perfil

To update the `list` command path, run `.\Install.ps1` again.

```powershell

echo $PROFILE## 🐛 Troubleshooting

```

### Command not found

---```powershell

. $PROFILE  # Reload your profile

## 📋 Lo que hace el Instalador```



El script `Install.ps1` es completamente **interactivo y seguro**:### Permission denied

```powershell

1. ✅ **Verifica** que exista tu perfil de PowerShell (lo crea si no existe)Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

2. ❓ **Pregunta** la ruta donde están tus repositorios```

3. ❓ **Pregunta** qué nombre quieres para el comando

4. ✏️ **Actualiza** `Constants.ps1` con tu ruta### Wrong repository path

5. ➕ **Agrega** una función a tu `$PROFILE` para ejecutar el scriptEdit the path in your `$PROFILE`:

6. 📦 **Migra** el archivo `.repo-aliases.json` si existe en tu carpeta de repos```powershell

notepad $PROFILE

---# Update the path in the 'list' function

```

## 🔄 Actualizar

## 📝 Version

Si cambiaste de PC o moviste tus repositorios:

**Version**: 2.0 (SOLID Refactored)  

```powershell**Author**: Martin Miguel Bernal Garcia  

.\Install.ps1**Date**: January 2026

```

## 📜 License

El instalador actualizará todas las rutas automáticamente.

Internal use only.

---

---

## 📜 Información del Proyecto

**Happy coding! 🚀**

**Versión:** 2.0 (Refactorizado con SOLID)  #   r e p o - n a v 

**Autor:** Martin Miguel Bernal Garcia   

**Fecha:** Enero 2026   
**Licencia:** Uso interno

---

## 🤝 Contribuir

Si encuentras bugs o tienes sugerencias:

1. 🐛 Reporta un [Issue](https://github.com/jobshimo/repo-nav/issues)
2. 🔀 Crea un [Pull Request](https://github.com/jobshimo/repo-nav/pulls)

---

## ⭐ ¿Te gusta este proyecto?

¡Dale una ⭐ en GitHub!

---

<div align="center">

**Hecho con ❤️ y PowerShell**

[🏠 Home](https://github.com/jobshimo/repo-nav) • [📝 Issues](https://github.com/jobshimo/repo-nav/issues) • [🔀 Pull Requests](https://github.com/jobshimo/repo-nav/pulls)

</div>
