# 📁 Repository Navigator# 📁 Repository Navigator# 📁 Repository Navigator



> **Una herramienta interactiva en PowerShell para gestionar múltiples repositorios Git con aliases, operaciones npm y seguimiento de estado.**



[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://github.com/PowerShell/PowerShell)> **Una herramienta interactiva en PowerShell para gestionar múltiples repositorios Git con aliases, operaciones npm y seguimiento de estado.**> **Una herramienta interactiva en PowerShell para gestionar múltiples repositorios Git con aliases, operaciones npm y seguimiento de estado.**

[![License](https://img.shields.io/badge/License-Internal-red.svg)](LICENSE)

![Status](https://img.shields.io/badge/Status-Active-success)



---[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://github.com/PowerShell/PowerShell)[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://github.com/PowerShell/PowerShell)



## 📖 Tabla de Contenidos[![License](https://img.shields.io/badge/License-Internal-red.svg)](LICENSE)[![License](https://img.shields.io/badge/License-Internal-red.svg)](LICENSE)



- [¿Qué es esto?](#-qué-es-esto)![Status](https://img.shields.io/badge/Status-Active-success)

- [Instalación](#-instalación)

- [Uso Rápido](#-uso-rápido)![Demo Preview](https://img.shields.io/badge/Status-Active-success)

- [Controles](#-controles)

- [Características](#-características)---

- [Configuración](#-configuración)

- [Estructura del Proyecto](#-estructura-del-proyecto)---

- [Troubleshooting](#-troubleshooting)

## 📖 Tabla de Contenidos

---

## 📖 Tabla de Contenidos

## 🎯 ¿Qué es esto?

- [¿Qué es esto?](#-qué-es-esto)

**Repository Navigator** es una interfaz de terminal interactiva que te permite:

- [Instalación](#-instalación)- [¿Qué es esto?](#-qué-es-esto)

- 📂 Navegar rápidamente entre todos tus repositorios

- 🏷️ Crear **aliases con colores** para identificar proyectos importantes- [Uso Rápido](#-uso-rápido)- [Instalación](#-instalación)

- 📊 Ver el **estado de Git** (branch, commits pendientes, cambios)

- 📦 Gestionar **node_modules** (instalar/eliminar)- [Controles](#-controles)- [Uso Rápido](#-uso-rápido)

- 🔄 **Clonar** nuevos repositorios

- 🗑️ Eliminar repositorios con confirmación de seguridad- [Características](#-características)- [Controles](#-controles)



---- [Configuración](#-configuración)- [Características](#-características)



## 🚀 Instalación- [Estructura del Proyecto](#-estructura-del-proyecto)- [Configuración](#-configuración)



### Requisitos- [Troubleshooting](#-troubleshooting)- [Estructura del Proyecto](#-estructura-del-proyecto)



- **PowerShell 5.1+** (viene con Windows)- [Troubleshooting](#-troubleshooting)

- **Git** instalado

- **npm** (opcional, solo si trabajas con proyectos Node.js)---



### Pasos---



**1️⃣ Clona o descarga este repositorio**## 🎯 ¿Qué es esto?



```powershell## 🎯 ¿Qué es esto?

git clone https://github.com/jobshimo/repo-nav.git

cd repo-nav**Repository Navigator** es una interfaz de terminal interactiva que te permite:

```

**Repository Navigator** es una interfaz de terminal interactiva que te permite:

**2️⃣ Ejecuta el instalador interactivo**

- 📂 Navegar rápidamente entre todos tus repositorios

```powershell

.\Install.ps1- 🏷️ Crear **aliases con colores** para identificar proyectos importantes- 📂 Navegar rápidamente entre todos tus repositorios

```

- 📊 Ver el **estado de Git** (branch, commits pendientes, cambios)- 🏷️ Crear **aliases con colores** para identificar proyectos importantes

**3️⃣ Sigue las instrucciones**

- 📦 Gestionar **node_modules** (instalar/eliminar)- 📊 Ver el **estado de Git** (branch, commits pendientes, cambios)

El instalador te preguntará:

- 📁 **Ruta de tus repositorios** (ej: `C:\Users\TuUsuario\repos`)- 🔄 **Clonar** nuevos repositorios- 📦 Gestionar **node_modules** (instalar/eliminar)

- 🔤 **Nombre del comando** (por defecto: `list`, pero puedes usar `repos`, `nav`, etc.)

- 🗑️ Eliminar repositorios con confirmación de seguridad- 🔄 **Clonar** nuevos repositorios

El instalador creará automáticamente tu archivo de configuración `.repo-config.json` con tus datos.

- 🗑️ Eliminar repositorios con confirmación de seguridad

**4️⃣ Recarga tu perfil de PowerShell**

---

```powershell

. $PROFILE---

```

## 🚀 Instalación

**5️⃣ ¡Listo! Ejecuta el comando**

## 🚀 Instalación

```powershell

list  # o el nombre que hayas elegido### Requisitos

```

### Requisitos

---

- **PowerShell 5.1+** (viene con Windows)

## 💡 Uso Rápido

- **Git** instalado- **PowerShell 5.1+** (viene con Windows)

Simplemente escribe el comando que configuraste (por defecto `list`) y navega con las flechas del teclado:

- **npm** (opcional, solo si trabajas con proyectos Node.js)- **Git** instalado

```powershell

list- **npm** (opcional, solo si trabajas con proyectos Node.js)

```

### Pasos

**Acciones disponibles:**

### Pasos

- 🔼🔽 Navega con las flechas

- ⏎ Presiona `Enter` para abrir el repositorio en esa ubicación**1️⃣ Clona o descarga este repositorio**

- 🏷️ Presiona `E` para asignar un alias con color

- 🔄 Presiona `G` para cargar el estado de Git de todos los repos1️⃣ **Clona o descarga este repositorio**



---```powershell



## ⌨️ Controlesgit clone https://github.com/jobshimo/repo-nav.git```powershell



| Tecla | Acción | Descripción |cd repo-navgit clone https://github.com/jobshimo/repo-nav.git

|:-----:|:-------|:------------|

| <kbd>↑</kbd> <kbd>↓</kbd> | **Navegar** | Muévete entre repositorios |```cd repo-nav

| <kbd>Enter</kbd> | **Abrir** | Abre el repositorio seleccionado (cambia el directorio) |

| <kbd>E</kbd> | **Editar Alias** | Crea o modifica el alias del repositorio |```

| <kbd>R</kbd> | **Remover Alias** | Elimina el alias del repositorio |

| <kbd>I</kbd> | **Install** | Ejecuta `npm install` en el repositorio |**2️⃣ Ejecuta el instalador interactivo**

| <kbd>X</kbd> | **Remove** | Elimina la carpeta `node_modules` |

| <kbd>C</kbd> | **Clone** | Clona un nuevo repositorio desde URL |2️⃣ **Ejecuta el instalador interactivo**

| <kbd>Del</kbd> | **Delete** | Elimina el repositorio (con confirmación) |

| <kbd>L</kbd> | **Load Status** | Carga el estado de Git del repo actual |```powershell

| <kbd>G</kbd> | **Load All** | Carga el estado de Git de **todos** los repos |

| <kbd>Q</kbd> / <kbd>Esc</kbd> | **Salir** | Cierra el navegador |.\Install.ps1```powershell



---```.\Install.ps1



## ✨ Características```



### 🏷️ Sistema de Aliases**3️⃣ Sigue las instrucciones**



Asigna **nombres cortos y colores** a tus repositorios favoritos:3️⃣ **Sigue las instrucciones**



```jsonEl instalador te preguntará:

{

  "mi-proyecto-largo-nombre": {- 📁 **Ruta de tus repositorios** (ej: `C:\Users\TuUsuario\repos`)El instalador te preguntará:

    "alias": "MPN",

    "color": "Green",- 🔤 **Nombre del comando** (por defecto: `list`, pero puedes usar `repos`, `nav`, etc.)- 📁 **Ruta de tus repositorios** (ej: `C:\Users\TuUsuario\repos`)

    "isFavorite": true

  }- 🔤 **Nombre del comando** (por defecto: `list`, pero puedes usar `repos`, `nav`, etc.)

}

```**4️⃣ Recarga tu perfil de PowerShell**



- Los repositorios con alias aparecen **primero** en la lista4️⃣ **Recarga tu perfil de PowerShell**

- **14 colores disponibles** para categorizar proyectos

- Fácil identificación visual```powershell



### 📊 Estado de Git. $PROFILE```powershell



Visualiza el estado de cada repositorio:```. $PROFILE



- 🌿 **Branch actual**```

- ⬆️ **Commits por enviar** (ahead)

- ⬇️ **Commits por recibir** (behind)**5️⃣ ¡Listo! Ejecuta el comando**

- 📝 **Cambios sin commitear**

5️⃣ **¡Listo! Ejecuta el comando**

### 📦 Gestión de npm

```powershell

- **Instalar dependencias** con `npm install`

- **Eliminar node_modules** para liberar espaciolist  # o el nombre que hayas elegido```powershell

- Operaciones interactivas con confirmación

```list  # o el nombre que hayas elegido

### 🗂️ Organización Inteligente

```

- Repositorios **favoritos primero**

- Orden **alfabético** automático---

- Búsqueda visual rápida

---

---

## 💡 Uso Rápido

## ⚙️ Configuración

## 💡 Uso Rápido

### 📁 Ubicación de Archivos

Simplemente escribe el comando que configuraste (por defecto `list`) y navega con las flechas del teclado:

Después de la instalación:

Simplemente escribe el comando que configuraste (por defecto `list`) y navega con las flechas del teclado:

```

repo-nav/```powershell

├── .repo-config.json         # ← Tu configuración personal (NO se sube a Git)

├── .repo-config.example.json # ← Plantilla de ejemplolist```powershell

├── .repo-aliases.json        # ← Aliases guardados (NO se sube a Git)

├── src/Config/Constants.ps1  # ← Constantes de la aplicación```list

└── ...

``````



> ⚠️ **Importante**: Los archivos `.repo-config.json` y `.repo-aliases.json` están en `.gitignore` y **NO se suben** al repositorio por contener información personal.**Acciones disponibles:**



### 🔧 Archivo de Configuración![Navigation Example](https://img.shields.io/badge/Example-Interactive%20UI-informational)



El archivo `.repo-config.json` contiene tu configuración personal:- 🔼🔽 Navega con las flechas



```json- ⏎ Presiona `Enter` para abrir el repositorio en esa ubicación

{

  "reposBasePath": "C:\\Users\\TuUsuario\\repos",- 🏷️ Presiona `E` para asignar un alias con color**Acciones disponibles:**

  "userName": "TuUsuario"

}- 🔄 Presiona `G` para cargar el estado de Git de todos los repos

```

- 🔼🔽 Navega con las flechas

**Para cambiar la configuración:**

---- ⏎ Presiona `Enter` para abrir el repositorio en esa ubicación

**Opción 1:** Vuelve a ejecutar el instalador

- 🏷️ Presiona `E` para asignar un alias con color

```powershell

.\Install.ps1## ⌨️ Controles- 🔄 Presiona `G` para cargar el estado de Git de todos los repos

```



**Opción 2:** Edita manualmente `.repo-config.json`

| Tecla | Acción | Descripción |---

```powershell

notepad .repo-config.json|:-----:|:-------|:------------|

```

| <kbd>↑</kbd> <kbd>↓</kbd> | **Navegar** | Muévete entre repositorios |## ⌨️ Controles

### 🎨 Colores Disponibles

| <kbd>Enter</kbd> | **Abrir** | Abre el repositorio seleccionado (cambia el directorio) |

| Color | Variante Oscura |

|-------|----------------|| <kbd>E</kbd> | **Editar Alias** | Crea o modifica el alias del repositorio || Tecla | Acción | Descripción |

| `Yellow` | `DarkYellow` |

| `Green` | `DarkGreen` || <kbd>R</kbd> | **Remover Alias** | Elimina el alias del repositorio ||:-----:|:-------|:------------|

| `Cyan` | `DarkCyan` |

| `Magenta` | `DarkMagenta` || <kbd>I</kbd> | **Install** | Ejecuta `npm install` en el repositorio || <kbd>↑</kbd> <kbd>↓</kbd> | **Navegar** | Muévete entre repositorios |

| `Blue` | `DarkBlue` |

| `Red` | `DarkRed` || <kbd>X</kbd> | **Remove** | Elimina la carpeta `node_modules` || <kbd>Enter</kbd> | **Abrir** | Abre el repositorio seleccionado (cambia el directorio) |

| `White` | `Gray` |

| <kbd>C</kbd> | **Clone** | Clona un nuevo repositorio desde URL || <kbd>E</kbd> | **Editar Alias** | Crea o modifica el alias del repositorio |

### 📝 Formato del Archivo de Aliases

| <kbd>Del</kbd> | **Delete** | Elimina el repositorio (con confirmación) || <kbd>R</kbd> | **Remover Alias** | Elimina el alias del repositorio |

El archivo `.repo-aliases.json` tiene esta estructura:

| <kbd>L</kbd> | **Load Status** | Carga el estado de Git del repo actual || <kbd>I</kbd> | **Install** | Ejecuta `npm install` en el repositorio |

```json

{| <kbd>G</kbd> | **Load All** | Carga el estado de Git de **todos** los repos || <kbd>X</kbd> | **Remove** | Elimina la carpeta `node_modules` |

  "nombre-del-repositorio": {

    "alias": "ALIAS-CORTO",| <kbd>Q</kbd> / <kbd>Esc</kbd> | **Salir** | Cierra el navegador || <kbd>C</kbd> | **Clone** | Clona un nuevo repositorio desde URL |

    "color": "Green",

    "isFavorite": true| <kbd>Del</kbd> | **Delete** | Elimina el repositorio (con confirmación) |

  },

  "otro-repositorio": {---| <kbd>L</kbd> | **Load Status** | Carga el estado de Git del repo actual |

    "alias": "OTRO",

    "color": "Cyan",| <kbd>G</kbd> | **Load All** | Carga el estado de Git de **todos** los repos |

    "isFavorite": true

  }## ✨ Características| <kbd>Q</kbd> / <kbd>Esc</kbd> | **Salir** | Cierra el navegador |

}

```



---### 🏷️ Sistema de Aliases---



## 📂 Estructura del Proyecto



El proyecto está organizado siguiendo **principios SOLID** y **patrones de diseño OOP**:Asigna **nombres cortos y colores** a tus repositorios favoritos:## ✨ Características



```

repo-nav/

│```json### 🏷️ Sistema de Aliases

├── 📄 repo-nav.ps1                # Punto de entrada principal

├── 📄 Install.ps1                 # Script de instalación{

├── 📄 README.md                   # Esta documentación

├── 📄 .repo-config.json           # Configuración personal (gitignored)  "mi-proyecto-largo-nombre": {Asigna **nombres cortos y colores** a tus repositorios favoritos:

├── 📄 .repo-config.example.json   # Ejemplo de configuración

├── 📄 .repo-aliases.json          # Aliases guardados (gitignored)    "alias": "MPN",

├── 📄 .gitignore                  # Archivos ignorados por Git

│    "color": "Green",```json

└── 📁 src/

    │    "isFavorite": true{

    ├── 📁 Config/                 # ⚙️ Configuración

    │   ├── Constants.ps1          #    Rutas y constantes  }  "mi-proyecto-largo-nombre": {

    │   └── ColorPalette.ps1       #    Paleta de colores

    │}    "alias": "MPN",

    ├── 📁 Models/                 # 📦 Modelos de datos

    │   ├── AliasInfo.ps1          #    Información de alias```    "color": "Green",

    │   ├── GitStatusModel.ps1     #    Estado de Git

    │   └── RepositoryModel.ps1    #    Modelo de repositorio    "isFavorite": true

    │

    ├── 📁 Services/               # 🔧 Lógica de negocio- Los repositorios con alias aparecen **primero** en la lista  }

    │   ├── AliasManager.ps1       #    Gestión de aliases

    │   ├── ConfigurationService.ps1 #  Configuración- **14 colores disponibles** para categorizar proyectos}

    │   ├── GitService.ps1         #    Operaciones Git

    │   ├── InteractiveHelpers.ps1 #    Helpers interactivos- Fácil identificación visual```

    │   ├── NpmHelpers.ps1         #    Helpers npm

    │   └── NpmService.ps1         #    Servicio npm

    │

    ├── 📁 UI/                     # 🎨 Interfaz de usuario### 📊 Estado de Git- Los repositorios con alias aparecen **primero** en la lista

    │   ├── ColorSelector.ps1      #    Selector de colores

    │   ├── ConsoleHelper.ps1      #    Utilidades de consola- **14 colores disponibles** para categorizar proyectos

    │   └── UIRenderer.ps1         #    Renderizado UI

    │Visualiza el estado de cada repositorio:- Fácil identificación visual

    └── 📁 Core/                   # 🧠 Núcleo de la aplicación

        ├── NavigationLoop.ps1     #    Loop de navegación

        ├── NavigatorController.ps1 #   Controlador principal

        └── RepositoryManager.ps1  #    Manager de repositorios- 🌿 **Branch actual**### 📊 Estado de Git

```

- ⬆️ **Commits por enviar** (ahead)

### 🏗️ Arquitectura

- ⬇️ **Commits por recibir** (behind)Visualiza el estado de cada repositorio:

- **Single Responsibility**: Cada clase tiene un propósito único y claro

- **Open/Closed**: Fácil de extender sin modificar código existente- 📝 **Cambios sin commitear**

- **Dependency Injection**: Dependencias inyectadas vía constructores

- **Facade Pattern**: `RepositoryManager` proporciona operaciones de alto nivel- 🌿 **Branch actual**

- **Separation of Concerns**: Capas separadas (Models, Services, UI, Core)

### 📦 Gestión de npm- ⬆️ **Commits por enviar** (ahead)

---

- ⬇️ **Commits por recibir** (behind)

## 🐛 Troubleshooting

- **Instalar dependencias** con `npm install`- 📝 **Cambios sin commitear**

### ❌ "El comando no se reconoce"

- **Eliminar node_modules** para liberar espacio

**Solución:** Recarga tu perfil de PowerShell

- Operaciones interactivas con confirmación### 📦 Gestión de npm

```powershell

. $PROFILE

```

### 🗂️ Organización Inteligente- **Instalar dependencias** con `npm install`

### ❌ "No se puede ejecutar el script (ExecutionPolicy)"

- **Eliminar node_modules** para liberar espacio

**Solución:** Cambia la política de ejecución

- Repositorios **favoritos primero**- Operaciones interactivas con confirmación

```powershell

Set-ExecutionPolicy -Scope CurrentUser RemoteSigned- Orden **alfabético** automático

```

- Búsqueda visual rápida### 🗂️ Organización Inteligente

Luego confirma con `Y` (Yes).



### ❌ "No se encontró el archivo de configuración"

---- Repositorios **favoritos primero**

Si es la primera vez que ejecutas la aplicación después de clonar el repositorio:

- Orden **alfabético** automático

```powershell

# Copia el archivo de ejemplo## ⚙️ Configuración- Búsqueda visual rápida

Copy-Item .repo-config.example.json .repo-config.json



# Edita con tus datos

notepad .repo-config.json### 📁 Ubicación de Archivos---

```



O simplemente ejecuta el instalador:

Después de la instalación:## ⚙️ Configuración

```powershell

.\Install.ps1

```

```### 📁 Ubicación de Archivos

### ❌ "Los repositorios no se encuentran"

repo-nav/

**Solución 1:** Re-ejecuta el instalador

├── .repo-aliases.json        # ← Aliases guardados aquíDespués de la instalación:

```powershell

.\Install.ps1├── src/Config/Constants.ps1  # ← Ruta de tus repositorios

```

└── ...```

**Solución 2:** Edita manualmente `.repo-config.json`

```repo-nav/

```powershell

notepad .repo-config.json├── .repo-aliases.json        # ← Aliases guardados aquí

```

### 🔧 Cambiar la Ruta de Repositorios├── src/Config/Constants.ps1  # ← Ruta de tus repositorios

Actualiza la ruta en `reposBasePath`.

└── ...

### ℹ️ Ver la ubicación de tu perfil

**Opción 1:** Vuelve a ejecutar el instalador```

```powershell

echo $PROFILE

```

```powershell### 🔧 Cambiar la Ruta de Repositorios

---

.\Install.ps1

## 📋 Lo que hace el Instalador

```**Opción 1:** Vuelve a ejecutar el instalador

El script `Install.ps1` es completamente **interactivo y seguro**:



1. ✅ **Verifica** que exista tu perfil de PowerShell (lo crea si no existe)

2. ❓ **Pregunta** la ruta donde están tus repositorios**Opción 2:** Edita manualmente `src/Config/Constants.ps1````powershell

3. ❓ **Pregunta** qué nombre quieres para el comando

4. ✏️ **Crea** el archivo `.repo-config.json` con tu configuración.\Install.ps1

5. ➕ **Agrega** una función a tu `$PROFILE` para ejecutar el script

6. 📦 **Migra** el archivo `.repo-aliases.json` si existe en tu carpeta de repos```powershell```



---static [string] $ReposBasePath = "C:\Tu\Nueva\Ruta"



## 🔄 Actualizar```**Opción 2:** Edita manualmente `src/Config/Constants.ps1`



Si cambiaste de PC o moviste tus repositorios:



```powershell### 🎨 Colores Disponibles```powershell

.\Install.ps1

```static [string] $ReposBasePath = "C:\Tu\Nueva\Ruta"



El instalador actualizará todas las rutas automáticamente.| Color | Variante Oscura |```



---|-------|----------------|



## 🔒 Seguridad y Privacidad| `Yellow` | `DarkYellow` |### 🎨 Colores Disponibles



Este proyecto está diseñado para **NO exponer información personal**:| `Green` | `DarkGreen` |



- ✅ Tu nombre de usuario **NO** se sube al repositorio| `Cyan` | `DarkCyan` || Color | Variante Oscura |

- ✅ Las rutas de tus proyectos **NO** se suben al repositorio

- ✅ Tus aliases personales **NO** se suben al repositorio| `Magenta` | `DarkMagenta` ||-------|----------------|

- ✅ Toda la configuración personal está en `.gitignore`

| `Blue` | `DarkBlue` || `Yellow` | `DarkYellow` |

Solo se sube el **código fuente** y archivos de ejemplo.

| `Red` | `DarkRed` || `Green` | `DarkGreen` |

---

| `White` | `Gray` || `Cyan` | `DarkCyan` |

## 📜 Información del Proyecto

| `Magenta` | `DarkMagenta` |

**Versión:** 2.0 (Refactorizado con SOLID)  

**Autor:** Martin Miguel Bernal Garcia  ### 📝 Formato del Archivo de Aliases| `Blue` | `DarkBlue` |

**Fecha:** Enero 2026  

**Licencia:** Uso interno| `Red` | `DarkRed` |



---El archivo `.repo-aliases.json` tiene esta estructura:| `White` | `Gray` |



## 🤝 Contribuir



Si encuentras bugs o tienes sugerencias:```json### � Formato del Archivo de Aliases



1. 🐛 Reporta un [Issue](https://github.com/jobshimo/repo-nav/issues){

2. 🔀 Crea un [Pull Request](https://github.com/jobshimo/repo-nav/pulls)

  "nombre-del-repositorio": {El archivo `.repo-aliases.json` tiene esta estructura:

---

    "alias": "ALIAS-CORTO",

## ⭐ ¿Te gusta este proyecto?

    "color": "Green",```json

¡Dale una ⭐ en GitHub!

    "isFavorite": true{

---

  },  "nombre-del-repositorio": {

<div align="center">

  "otro-repositorio": {    "alias": "ALIAS-CORTO",

**Hecho con ❤️ y PowerShell**

    "alias": "OTRO",    "color": "Green",

[🏠 Home](https://github.com/jobshimo/repo-nav) • [📝 Issues](https://github.com/jobshimo/repo-nav/issues) • [🔀 Pull Requests](https://github.com/jobshimo/repo-nav/pulls)

    "color": "Cyan",    "isFavorite": true

</div>

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
