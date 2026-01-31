# REPO-NAV

> **Mi navegador de repositorios en PowerShell** — gestión de Git, npm y organización de proyectos desde la terminal.

![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue?logo=powershell)
![Private](https://img.shields.io/badge/License-Private-red)
![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey)
![Tests](https://img.shields.io/badge/Tests-Pester-green)

---

## ¿Por Qué Hice Esto?

Tengo muchos repositorios. Demasiados, probablemente. Y me cansé de hacer `cd ../otro-proyecto` veinte veces al día, de olvidar en qué rama estaba cada repo, y de tener que abrir el explorador para recordar si ya había borrado los `node_modules` de ese proyecto que no toco hace meses.

Empecé con un script de 200 líneas que simplemente listaba carpetas. Pero me enganchó. Quería alias con colores para identificar los repos al vuelo. Quería ver el estado de Git sin ejecutar comandos. Quería que fuera rápido y bonito.

Lo que comenzó como una herramienta práctica se convirtió en un proyecto donde apliqué todo lo que sabía sobre arquitectura de software. PowerShell no es el lenguaje más cómodo para hacer OOP, pero eso fue parte del reto. Cada problema que encontré me obligó a buscar soluciones creativas, y eso es lo que más disfruté.

**El resultado**: una aplicación que uso todos los días en mi trabajo y que ahora es un proyecto robusto con tests, CI/CD y una arquitectura modular sólida.

---

## ¿Qué Hace?

### 📂 Navegación Inteligente
- **Lista interactiva** de todos mis repositorios con navegación por teclado
- **Navegación jerárquica**: entro y salgo de carpetas contenedoras
- **Búsqueda instantánea**: escribo directamente o pulso `/` para filtrar
- **Favoritos**: los repos que más uso aparecen primero

### 🎨 Personalización Visual
- **Alias con colores**: identifico cada repo de un vistazo (Angular = rojo, APIs = verde, etc.)
- **Temas**: selecciono colores y estilos a mi gusto
- **Modos visuales**: minimalista o completo según el día
- **Idiomas**: Español (nativo) e Inglés

### 🔀 Integración Profunda con Git
- **Rama actual** visible al instante en cada repositorio
- **Indicadores de estado**: cambios sin commit (●) y commits sin push (↑)
- **Carga paralela**: consulto el estado de 50 repositorios sin bloquear la interfaz
- **Quick Changes**: flujo rápido para commits y push sin salir de la herramienta

### 📦 Gestión de Proyectos
- **npm install** con una tecla (`I`)
- **Limpieza de node_modules** instantánea (`X`) para recuperar espacio
- **Clonar y Organizar**: gestión de carpetas y repositorios desde la UI

---

## Lo Que Más Disfruté Creando Esto

### El Reto de PowerShell + OOP + SOLID
PowerShell no está diseñado para aplicaciones grandes, pero decidí aplicar **SOLID** estrictamente.
- **Inyección de Dependencias**: Implementé mi propio contenedor de DI (`AppBuilder`) para desacoplar componentes.
- **Patrones de Diseño**: Uso intensivo de *Command*, *Factory*, *Strategy* y *Observer*.
- **Arquitectura por Capas**: Separación clara entre Modelos, Servicios, UI y Core.

### Testing Profesional
No quería un script frágil. Implementé un framework de pruebas robusto usando **Pester 5**.
- **Unit Tests** para cada servicio y helper.
- **Code Coverage** para asegurar que no dejo nada al azar.
- **Git Hooks**: Un `pre-push` hook que ejecuta los tests automáticamente y bloquea el push si rompo algo.

### Estandarización
Aunque es PowerShell, uso **npm** como *Task Runner*. Esto me da un flujo de trabajo profesional y estándar: `npm test`, `npm run build`, `npm start`.

---

## Requisitos

| Requisito | Versión | Notas |
|-----------|---------|-------|
| **PowerShell** | 5.1+ | Necesario (usa clases y características modernas) |
| **Git** | Cualquiera | Para las funciones de control de versiones |
| **npm** | Cualquiera | *Opcional* para gestión de paquetes Node |

---

## Instalación y Uso

### Desarrollo (Código Fuente)

```bash
# Clonar
git clone https://github.com/tuusuario/repo-nav.git
cd repo-nav

# Instalar dependencias del entorno (hooks)
npm run prepare

# Iniciar
npm start
```

### Comandos de Desarrollo
Gracias al `package.json`, todo está estandarizado:

```bash
# Ejecutar la aplicación
npm start

# Ejecutar tests (Pester)
npm test

# Ejecutar tests con reporte de cobertura
npm run test:coverage

# Validar todo el proyecto (Lint + Tests + Build)
npm run check

# Validar solo estructura y compilación
npm run verify

# Generar versión distribuible (un solo archivo)
npm run build
```

---

## Arquitectura

El proyecto sigue una arquitectura estricta por capas:

```
src/
├── Config/               # Constantes y configuración global
├── Models/               # Estructuras de datos (sin lógica)
├── Services/             # Lógica de negocio pura (Git, NPM, Files)
├── Global/               # Helpers y Utilidades estáticas
├── Core/                 # El corazón del sistema
│   ├── Commands/         # Lógica de los comandos de usuario (Command Pattern)
│   ├── Engine/           # Bucle principal y manejo de entrada
│   └── State/            # Gestión del estado de la aplicación
├── UI/                   # Todo lo visible
│   ├── Components/       # Widgets reutilizables
│   └── Views/            # Pantallas completas
└── Startup/              # Composition Root (DI y Bootstrapping)
```

---

## Autor

**Martin Miguel Bernal Garcia**  
*Ingeniero de Software & Entusiasta de la Terminal*

Hecho con ❤️ y mucho café. Si te resulta útil o curioso, ¡disfrútalo!
