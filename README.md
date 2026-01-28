# REPO-NAV

> **Mi navegador de repositorios en PowerShell** — gestión de Git, npm y organización de proyectos desde la terminal.

---

## Cómo Surgió

Empecé repo-nav como un script simple para resolver algo que me pasaba constantemente: tenía muchos repositorios y perdía tiempo navegando entre ellos. Quería algo rápido, con alias cortos y colores para identificarlos al vuelo.

Lo que comenzó con ~200 líneas creció hasta convertirse en esto. No porque necesitara algo tan grande, sino porque me sirvió para practicar arquitectura de software y principios SOLID en un lenguaje que normalmente no se usa así (PowerShell).

El resultado es una herramienta que uso todos los días y que espero te sea útil también.

---

## ¿Qué Hace?

### 📂 Navegación de Repositorios
- Navego con las **flechas** por la lista de repos
- Entro y salgo de **carpetas contenedoras** (jerarquía)
- La lista se **pagina automáticamente** según el tamaño de la terminal
- Busco repos escribiendo directamente o con `/`
- Puedo **ocultar cabeceras** para ganar espacio

### 🏷️ Organización
- **Alias personalizados** con colores (para identificar repos de un vistazo)
- **Favoritos** que aparecen primero en la lista
- **Crear carpetas** para organizar mis proyectos
- **Clonar repos** directamente con la URL
- **Eliminar repos** (con confirmación para no liarla)

### 🔀 Integración con Git
- Veo la **rama actual** de cada repo
- Indicadores de **cambios sin commitear** y **commits sin pushear**
- **Carga paralela**: consulta el estado de todos los repos sin bloquear la interfaz
- **Flujo de integración**: selecciono ramas origen/destino y me genera la URL del PR

### 📦 Integración con npm
- Ejecuto `npm install` desde aquí (`I`)
- Borro `node_modules` de un repo con una tecla (`X`)
- Veo qué repos tienen `node_modules`

### ⚙️ Personalización
- **Idiomas**: Español e Inglés
- **Temas**: colores de selección, fondo, estilo de alias
- **Modos de menú**: Completo, Minimalista u Oculto
- **Modo compacto**: oculta cabeceras para ver más repos

---

## Requisitos

| Requisito | Versión | Notas |
|-----------|---------|-------|
| **PowerShell** | 5.1+ | Necesario (usa clases y características modernas) |
| **Git** | Cualquiera | Para las funciones de control de versiones |
| **npm** | Cualquiera | *Opcional* — solo si gestionas proyectos Node.js |

---

## Instalación

### 1. Clonar

```powershell
git clone https://github.com/tuusuario/repo-nav.git
cd repo-nav
```

### 2. Ejecutar el Setup

```powershell
.\Setup.ps1
```

El asistente:
- Verifica que tengas PowerShell, Git y npm
- Te pide la ruta donde guardas tus repositorios
- Crea un comando en tu perfil de PowerShell
- Genera los archivos de configuración

### 3. Recargar el Perfil

```powershell
. $PROFILE
```

O simplemente reinicia la terminal.

### 4. Lanzar

```powershell
list
```

(O el nombre que hayas elegido durante el setup: `repo`, `nav`, etc.)

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

## Configuración

| Archivo | Para qué sirve | ¿Se sube a Git? |
|---------|----------------|-----------------|
| `.repo-config.json` | Tu ruta de repos y nombre de usuario | No |
| `.repo-aliases.json` | Tus alias y favoritos | No |
| `.repo-preferences.json` | Preferencias de interfaz | No |
| `.repo-config.example.json` | Plantilla de ejemplo | Sí |

---

## Estructura del Proyecto

```
repo-nav/
├── repo-nav.ps1              # Punto de entrada
├── Setup.ps1                 # Instalador
├── src/
│   ├── Config/               # Constantes y paleta de colores
│   ├── Models/               # Modelos de datos (Repository, GitStatus...)
│   ├── Services/             # Lógica de negocio (Git, npm, búsqueda...)
│   ├── UI/                   # Interfaz (renderers, vistas, selectores)
│   └── Core/                 # Motor (estado, comandos, factory)
```

---

## Cómo Está Hecho

Intenté aplicar buenas prácticas aunque PowerShell no sea el lenguaje más cómodo para ello:

- **Modular**: cada clase en su archivo, responsabilidades separadas
- **Inyección de dependencias**: gestionada manualmente en `AppBuilder.ps1`
- **Patrón Command**: cada acción (navegar, clonar, buscar...) es un comando independiente
- **Código claro**: nombres descriptivos y tipado fuerte para que sea fácil de entender

Para el rendimiento:
- **Git en paralelo**: usa un pool de Runspaces para no congelar la UI
- **Lazy loading**: solo cargo el estado Git cuando lo necesito
- **Renderizado parcial**: solo repinto lo que cambia
- **Dirty flags**: evito redibujar la pantalla completa innecesariamente

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

**No encuentro la configuración:**
```powershell
.\Setup.ps1
```

---

## Privacidad

Todos los archivos con datos personales están en `.gitignore`:
- Tu nombre de usuario no se sube
- Tus rutas no se suben
- Tus alias y favoritos no se suben

Solo se versiona el código fuente.

---

## Historial

| Versión | Qué cambió |
|---------|------------|
| **2.1** | Mejoras de UI, preferencias de cabecera, Git Flow, navegación |
| **2.0** | Rediseño con principios SOLID |
| **1.0** | Script original con navegación y alias |

---

## Autor

**Martin Miguel Bernal Garcia**  
Enero 2026

---

*Hecho en PowerShell para quienes vivimos en la terminal.*
