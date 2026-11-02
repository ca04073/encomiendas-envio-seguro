---
proyecto: "{{PROJECT_NAME}}"
tipo: "Plantilla Base / Repositorio Modelo"
entorno_principal: "Podman / OCI Containers"
arquitectura: "Separación Modular / Staging -> Main"
estado: "En Desarrollo / Plantilla Lista"
version: "1.0.0"
ultima_actualizacion: "2026-10-25"
tags:
  - template
  - devcontainer
  - github-actions
  - ghcr
  - podman
---

# 🚀 {{PROJECT_NAME}}

> [!NOTE]
> **REPOSITORIO PLANTILLA (TEMPLATE):**  
> Este proyecto define la línea base de desarrollo, gobierno de código y pipelines de integración continua. Emplea un ciclo de dos ramas (`develop` para integración y pruebas, y `main` para entregables estables de producción).

---

### 🛡️ Estado del Proyecto y Métricas

![GitHub default branch](https://shields.io)
![Main Protected](https://shields.io)
![Container Runtime](https://shields.io)
![Registry](https://shields.io)
![License](https://shields.io)

---

## ⚡ 1. Resumen del Sistema

{{PROJECT_DESCRIPTION}}

Principios del entorno:
1. **Contenedorización Agnóstica:** Listo para compilar y ejecutarse sin fricción con **Podman** o **Docker** mediante definiciones estándar OCI.
2. **Entornos Reproducibles:** Soporte nativo para **Dev Containers** vía `.devcontainer/devcontainer.json` para VS Code o GitHub Codespaces.
3. **Gestión Ágil y Trazabilidad:** Planificación de requerimientos centralizada en `BACKLOG.md` e historial evolutivo estricto regulado bajo el estándar de `CHANGELOG.md`.

---

## 📊 2. Especificación Técnica y Gobernanza

| Componente | Definición / Herramienta | Propósito / Alcance |
| :--- | :--- | :--- |
| **Rama Base (`develop`)** | Default branch | Integración continua, staging y recepción de PRs diarios. |
| **Rama Producción (`main`)** | Protected branch | Entregas estables; bloqueada a commits directos y auto-merges. |
| **Gobernanza de Revisiones** | `.github/CODEOWNERS` | Exige aprobación formal de revisores asignados antes del merge. |
| **Estandarización de PRs** | `PULL_REQUEST_TEMPLATE.md` | Checklist obligatorio de calidad, pruebas y variables de entorno. |
| **Registro de Imágenes** | GitHub Packages (GHCR) | Publicación automática de imágenes OCI (`:staging` y `:latest`). |

---

## 🏗️ 3. Arquitectura del Flujo de Trabajo (Git Workflow)

```text
[ Feature Branch ] ────── (Pull Request) ──────► [ develop (Staging) ]
                                                        │
                               (PR con Aprobación + CI) │
                                                        ▼
                                                [ main (Producción) ]
                                                        │
                                                        ▼
                                                [ GHCR Tag: :latest ]
```

### Reglas de Contribución

- **Commits directos en `main` prohibidos:** Todo cambio debe originarse mediante un Pull Request desde `develop`.
- **Trazabilidad de tareas:** Cada Pull Request o Issue debe incluir obligatoriamente en su título el identificador de la tarea correspondiente del `BACKLOG.md` (ej. `[ID-001]`).
- **Aprobación de Code Owners:** El PR debe contar con la firma aprobada de los revisores designados en el archivo `CODEOWNERS`.
- **CI en Verde:** El pipeline de GitHub Actions debe compilar la imagen y validar el código satisfactoriamente antes de autorizar el merge.

---

## 📂 4. Árbol Estructural del Repositorio

```text
.
├── .devcontainer/
│   └── devcontainer.json         # Configuración del entorno de desarrollo aislado
├── .github/
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md         # Plantilla estructurada para reporte de errores
│   │   ├── config.yml            # Configuración para deshabilitar issues vacíos
│   │   └── feature_request.md    # Plantilla estructurada para nuevas propuestas
│   ├── workflows/
│   │   └── ci.yml                # Pipeline de GitHub Actions (Lint, Build y GHCR)
│   ├── CODEOWNERS                # Asignación obligatoria de revisores
│   └── PULL_REQUEST_TEMPLATE.md  # Checklist de verificación para Pull Requests
├── .env.example                  # Plantilla de variables de entorno públicas
├── .gitignore                    # Exclusiones de Git
├── BACKLOG.md                    # Listado priorizado de tareas y estimación en días
├── CHANGELOG.md                  # Historial detallado de cambios por versión (SemVer)
├── compose.yaml                  # Orquestación multicontenedor (compatible con Podman)
├── Dockerfile                    # Receta de construcción OCI del contenedor
└── README.md                     # Documentación general del proyecto
```

---

## 🚀 5. Puesta en Marcha y Entorno Local

### 5.1. Requisitos Previos

- **Motor de contenedores:** [Podman](https://podman.io) (recomendado) o Docker Engine / Docker Desktop.
- **Cliente Git:** Versión 2.30+ instalada y configurada.

### 5.2. Configuración Inicial

1. Clonar el repositorio y entrar en la carpeta del proyecto:
    
    ```bash
    git clone https://github.com/{{GITHUB_OWNER}}/{{PROJECT_NAME}}.git
    cd {{PROJECT_NAME}}
    ```
    
2. Preparar el archivo de variables de entorno:
    
    ```bash
    cp .env.example .env
    ```

### 5.3. Construcción y Ejecución con Podman / Docker

Compilar la imagen localmente:

```bash
podman build -t {{PROJECT_NAME}}:local .
```

Levantar el entorno con compose:

```bash
podman compose up -d
```

> [!TIP]
> Si utilizas **Podman** en Linux en modo _rootless_, no necesitas permisos de superusuario (`sudo`) para interactuar con los contenedores o el orquestador.

---

## 📦 6. Descarga de Imágenes desde GHCR

Para utilizar directamente los artefactos generados por el pipeline de integración continua:

```bash
# Versión de staging (rama develop)
podman pull ghcr.io/{{GITHUB_OWNER}}/{{PROJECT_NAME}}:staging

# Versión de producción (rama main)
podman pull ghcr.io/{{GITHUB_OWNER}}/{{PROJECT_NAME}}:latest
```

---
> **Mantenimiento y Autoría:** @{{GITHUB_OWNER}}
