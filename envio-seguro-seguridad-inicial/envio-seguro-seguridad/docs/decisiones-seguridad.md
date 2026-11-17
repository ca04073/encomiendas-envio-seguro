# Decisiones de seguridad — Envío Seguro

## Estado

Documento inicial de decisiones para la Parte 4. Las decisiones marcadas como **pendientes** no deben tratarse como configuración ya implementada.

## 1. Modelo de control de acceso

Se utilizará RBAC (*Role-Based Access Control*): los privilegios se conceden a roles grupales y las cuentas personales reciben membresía en esos roles.

Los roles grupales iniciales son:

- `rol_dba`
- `rol_gerencia`
- `rol_encargado_sucursal`
- `rol_recepcionista`
- `rol_repartidor`
- `rol_contabilidad`
- `rol_auditor`
- `rol_backup`

Los roles grupales se definen como `NOLOGIN`. Las cuentas personales se crearán separadamente.

## 2. Principio de mínimo privilegio

Ningún rol funcional tendrá `SUPERUSER`, `CREATEDB`, `CREATEROLE`, `REPLICATION` o `BYPASSRLS`.

`rol_dba` es inicialmente un rol de grupo y **no equivale** al superusuario interno de PostgreSQL. Sus permisos administrativos sobre objetos se definirán explícitamente en una fase posterior.

## 3. Conectividad y esquema

En la primera fase se concede `CONNECT` a los roles definidos y `USAGE` sobre `public`. No se concede `CREATE` sobre `public` a los roles funcionales.

No se revoca todavía `CONNECT` de `PUBLIC`: antes debe inventariarse si existen otras cuentas o aplicaciones que dependan de ese permiso. Esta decisión evita un bloqueo colateral durante la instalación inicial.

## 4. Información que requiere protección

El modelo contiene datos personales y operativos, entre ellos DUI, NIT/NRC, teléfonos, correos, direcciones, pagos, DTE, trazabilidad e incidencias. Los permisos por tabla/columna y las vistas de exposición se definirán después de construir la matriz rol-operación.

## 5. Seguridad por sucursal

**Pendiente.** Se evaluará Row-Level Security (RLS) para limitar filas según la sucursal del usuario. RLS requiere definir cómo se establece y valida la identidad de sucursal en cada sesión; no basta con conceder permisos por tabla.

## 6. Respaldos

**Pendiente.** Se separarán respaldos lógicos (`pg_dump`) y físicos (`pg_basebackup`), así como el archivado WAL para PITR. Las credenciales y permisos de la cuenta técnica se diseñarán por separado. No se guardarán contraseñas ni respaldos en Git.

## 7. Auditoría y trazabilidad

**Pendiente.** Se definirán los eventos que deben auditarse, la retención de registros y quién puede consultarlos. Los roles operativos no deberían poder borrar o alterar libremente la evidencia de trazabilidad.

## 8. Reglas del repositorio

- Versionar scripts SQL y documentación.
- No versionar secretos, copias de seguridad ni datos personales reales.
- Usar `psql -v ON_ERROR_STOP=1` al ejecutar archivos.
- Verificar host, puerto, versión y base antes de cambios.
- Probar scripts en una instancia de desarrollo antes de producción.




# Matriz inicial de privilegios

| Rol | Alcance principal | Restricciones relevantes |
|---|---|---|
| `rol_dba` | SELECT, INSERT, UPDATE, DELETE en tablas existentes | No es SUPERUSER; sin DDL implícito, TRUNCATE, TRIGGER ni REFERENCES |
| `rol_gerencia` | Lectura de información empresarial, logística y financiera seleccionada | Sin DML |
| `rol_encargado_sucursal` | Lectura operativa; gestión de rutas, asignaciones e incidencias | Sin DELETE; alcance por sucursal pendiente de RLS |
| `rol_recepcionista` | Alta/actualización de clientes; alta de encomiendas, guías, eventos y pagos | Sin DELETE; no actualiza pagos |
| `rol_repartidor` | Lectura logística; inserta eventos e incidencias | Solo actualiza `fecha_llegada` y `observaciones` en asignaciones |
| `rol_contabilidad` | Lectura y gestión de pagos y DTE | Sin DELETE |
| `rol_auditor` | SELECT en todas las tablas existentes | Solo lectura |
| `rol_backup` | SELECT en todas las tablas existentes para backup lógico | No equivale a privilegios de backup físico |

## Advertencias y trabajo pendiente

1. PostgreSQL acumula privilegios: un usuario miembro de varios roles recibe la unión de los privilegios heredables.
2. Los GRANT a nivel de tabla no filtran filas. RLS debe implementar el aislamiento por sucursal.
3. Los permisos de secuencias/columnas de identidad deben validarse en la siguiente fase.
4. El acceso de recepción a `pago` se limita a INSERT; contabilidad gestiona actualizaciones y anulaciones mediante estados.
5. La matriz es una propuesta inicial que debe contrastarse con los procedimientos reales de la empresa.
