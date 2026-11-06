# Changelog (Historial de Cambios) 📜

Todos los cambios notables de este proyecto serán documentados en este archivo. El formato está basado en [Keep a Changelog](https://keepachangelog.com) y este proyecto se adhiere a [Versionado Semántico](https://semver.org).

## 📌 Tipos de Cambios
- `Added`: Para nuevas características.
- `Changed`: Para cambios en funcionalidades existentes.
- `Deprecated`: Para características que se eliminarán en próximas versiones.
- `Removed`: Para características eliminadas en esta versión.
- `Fixed`: Para cualquier resolución de bugs o errores.
- `Security`: En caso de vulnerabilidades o mejoras de seguridad.

---

## [Unreleased]
*Cambios confirmados y mezclados en la rama principal que aún no se han incluido en una versión/tag oficial.*

### Added
- [ ] Incorporación de nuevos módulos o servicios pendientes de liberar.

---

## [1.0.0] - 2026-11-05
*Primera versión estable del proyecto.*

### Added
- [ID-002] Actualización de la documentación técnica y badges en [`README.md`](README.md).
- Esquema relacional inicial de base de datos en PostgreSQL ([`database/schema.sql`](database/schema.sql)) cubriendo estructura de empresa, clientes, encomiendas, tarifas, rutas, pagos, eventos de rastreo, DTE e incidencias.
- Documento de especificación técnica de modelo de datos ([`docs/Envio-Seguro-Entidades-y-Atributos.pdf`](docs/Envio-Seguro-Entidades-y-Atributos.pdf)).

---

## 🛑 Guía de Formato (Copiar para Nueva Versión)

Cuando liberes una nueva versión, copia este bloque debajo de `## [Unreleased]`, reemplaza las variables y clasifica tus cambios:

```markdown
## [X.Y.Z] - AAAA-MM-DD

### Added
- Descripción del cambio o vinculación al ID del backlog.

### Changed
- Descripción del cambio.

### Fixed
- Descripción del bug corregido.
```

---

## 🔗 Enlaces de Comparación (Configuración de GitHub)
*Reemplaza `usuario` y `repositorio` por los datos reales de tu proyecto para activar los enlaces.*
*Configurar una sola vez al crear el repositorio a partir del template.*

[Unreleased]: https://github.com/ca04073/encomiendas-envio-seguro/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/ca04073/encomiendas-envio-seguro/releases/tag/v1.0.0
