# ENVÍO-SEGURO --- Seguridad de la base de datos

Este directorio contiene los scripts SQL y la documentación para
configurar, comprobar y auditar los controles de acceso de la base de
datos **ENVÍO-SEGURO** mediante PostgreSQL 17.

> **Estado:** los scripts `07_probar_permisos_roles.sql` y
> `08_auditoria_final_seguridad.sql` se ejecutaron sin errores de
> ejecución. Esto no equivale, por sí solo, a certificar que todos los
> controles estén correctamente configurados: deben revisarse los
> resultados y las observaciones que produzcan.

## Estructura

``` text
envio-seguro-seguridad/
├── docs/
│   ├── decisiones-seguridad.md
│   ├── diccionario de permisos de usuarios.md
│   └── manual-seguridad.md
├── scripts/
│   ├── 00_verificar_entorno.sql
│   ├── 01_crear_roles.sql
│   ├── 02_configurar_permisos.sql
│   ├── 03_crear_usuarios.sql
│   ├── 04_auditar_usuarios.sql
│   ├── 05_permisos_secuencias.sql
│   ├── 06_crear_estructura_seguridad.sql
│   ├── 07_probar_permisos_roles.sql
│   └── 08_auditoria_final_seguridad.sql
├── .gitignore
└── README.md
```

## Objetivo

Organizar los controles de seguridad de la base de datos en torno a:

-   **RBAC (Role-Based Access Control):** asignación de permisos
    mediante roles funcionales.
-   **Mínimo privilegio:** conceder únicamente las operaciones
    necesarias para cada función.
-   **Auditoría:** inspeccionar usuarios, roles, membresías y
    privilegios efectivos.
-   **Separación de funciones:** distinguir administración, operación,
    auditoría y respaldo.
-   **Preparación para seguridad por filas:** disponer de estructuras
    auxiliares para asociar usuarios con sucursales o repartidores.

## Roles funcionales

Los roles grupales son `NOLOGIN`; las cuentas personales son las que se
autentican y reciben la membresía correspondiente.

  -----------------------------------------------------------------------
  Rol                                 Función prevista
  ----------------------------------- -----------------------------------
  `rol_dba`                           Administración operativa de datos,
                                      sin asumir automáticamente
                                      privilegios de superusuario ni DDL.

  `rol_gerencia`                      Consulta de información empresarial
                                      para supervisión.

  `rol_encargado_sucursal`            Operación y consulta dentro de las
                                      responsabilidades de sucursal.

  `rol_recepcionista`                 Atención y registro de clientes,
                                      encomiendas, guías, eventos y pagos
                                      según la matriz.

  `rol_repartidor`                    Consulta logística y actualización
                                      limitada de información de reparto;
                                      registro de eventos e incidencias.

  `rol_contabilidad`                  Consulta y gestión de pagos y
                                      documentos tributarios según la
                                      matriz.

  `rol_auditor`                       Consulta para revisión y
                                      verificación.

  `rol_backup`                        Consulta necesaria para tareas de
                                      respaldo, según el alcance
                                      definido.
  -----------------------------------------------------------------------

Cuentas de ejemplo creadas por el proyecto:

-   `usr_dba_01`
-   `usr_gerencia_01`
-   `usr_encargado_sucursal_01`
-   `usr_recepcionista_01`
-   `usr_repartidor_01`
-   `usr_contabilidad_01`
-   `usr_auditor_01`
-   `usr_backup_01`

La asignación concreta de privilegios debe consultarse en
`docs/diccionario de permisos de usuarios.md` y en
`scripts/02_configurar_permisos.sql`. La pertenencia a varios roles
puede acumular permisos; por ello deben revisarse también las membresías
efectivas.

## Orden de ejecución

Ejecutar los scripts en este orden, conectándose primero a la base de
datos de destino:

1.  `00_verificar_entorno.sql` --- comprueba el contexto y el entorno de
    ejecución.
2.  `01_crear_roles.sql` --- crea los roles grupales.
3.  `02_configurar_permisos.sql` --- aplica la matriz de privilegios.
4.  `03_crear_usuarios.sql` --- crea las cuentas de inicio de sesión y
    asigna membresías.
5.  Establecer contraseñas individualmente con
    `\password nombre_usuario` desde `psql`.
6.  `05_permisos_secuencias.sql` --- inspecciona los permisos
    relacionados con secuencias e identidades.
7.  `06_crear_estructura_seguridad.sql` --- crea el esquema y los
    objetos auxiliares de seguridad.
8.  Cargar y mantener los mapeos de usuario a sucursal/repartidor cuando
    corresponda.
9.  `04_auditar_usuarios.sql` --- audita la configuración de usuarios y
    privilegios.
10. `07_probar_permisos_roles.sql` --- ejecuta pruebas de permisos
    previstas por el script.
11. `08_auditoria_final_seguridad.sql` --- genera la revisión final
    definida por el script.

Los números de archivo no representan necesariamente el orden operativo
completo: el script `05` se ejecuta antes de `06` en esta secuencia
porque son comprobaciones independientes de la estructura auxiliar.
Revisar siempre los comentarios y dependencias de cada script antes de
ejecutarlo en otro entorno.

## Ejecución desde `psql` en Windows

Ejemplo de conexión:

``` text
psql -U postgres -d envio_seguro
```

Dentro de `psql`, verificar la base activa:

``` sql
SELECT current_database(), current_user, session_user;
```

Ejecutar cada archivo mediante `\i` (la ruta identifica el archivo; no
cambia la base de datos):

``` text
\i C:/ruta/al/proyecto/scripts/00_verificar_entorno.sql
```

Repetir para el resto de los archivos. También se puede ejecutar un
script desde la terminal:

``` text
psql -U postgres -d envio_seguro -f "C:/ruta/al/proyecto/scripts/00_verificar_entorno.sql"
```

Usar rutas con `/` en los comandos de `psql` en Windows evita problemas
de interpretación de las barras invertidas.

## Auditoría sin modificar los datos

Los scripts de auditoría y prueba deben tratarse como herramientas de
observación. Antes de ejecutarlos:

-   Confirmar la base de datos con `current_database()`.
-   Leer el encabezado y los comentarios del script.
-   Verificar que no contenga `GRANT`, `REVOKE`, `CREATE ROLE`,
    `ALTER ROLE`, `DROP`, `INSERT`, `UPDATE` o `DELETE` sobre objetos
    permanentes, salvo que el propósito documentado requiera
    expresamente otra cosa.
-   Preferir una cuenta de auditoría con privilegios de lectura
    suficientes, sin privilegios administrativos.
-   Guardar la salida de ejecución como evidencia fechada y protegida.

Las tablas temporales (`TEMP`) pueden utilizarse para cálculos
intermedios sin dejar tablas permanentes en el esquema de negocio. No
obstante, una tabla temporal no vuelve automáticamente de solo lectura a
todo el script. La garantía depende de las sentencias ejecutadas y de
los privilegios de la cuenta.

## Protección de credenciales y evidencias

-   No incluir contraseñas en archivos `.sql`, repositorios, capturas,
    documentación ni comandos que queden en el historial.
-   Establecer contraseñas con `\password usuario` desde `psql`; no
    reutilizar contraseñas entre cuentas.
-   Custodiar las credenciales administrativas en un gestor de
    contraseñas con acceso restringido.
-   No utilizar la cuenta de superusuario para tareas cotidianas.
-   Mantener separadas, en lo posible, las funciones de DBA, auditoría y
    respaldo.
-   Exportar los registros y resultados de auditoría a un destino
    externo con acceso restringido y retención definida.
-   Proteger el repositorio y revisar los cambios antes de aceptar
    modificaciones a los scripts de seguridad.

Un administrador con privilegios suficientes en el servidor puede
modificar objetos y registros locales. Por eso, la evidencia destinada a
detectar acciones administrativas debe enviarse a un sistema externo que
la cuenta auditada no pueda modificar ni borrar.

## Alcance y pendientes conocidos

1.  La existencia de `seguridad.usuario_sucursal`,
    `seguridad.usuario_repartidor` y de funciones auxiliares no
    significa que el aislamiento por fila esté activo.
2.  Deben verificarse la carga de los mapeos, la creación de políticas y
    la activación de RLS en las tablas correspondientes. Hasta completar
    y probar esos pasos, no debe afirmarse que existe aislamiento
    efectivo por sucursal o repartidor.
3.  La auditoría de privilegios no sustituye una auditoría de cambios
    administrativos ni un registro externo e inmutable.
4.  La ejecución sin errores de los scripts `07` y `08` confirma que
    terminaron sin error SQL, pero sus resultados deben analizarse para
    determinar conformidad.
5.  Deben revisarse membresías adicionales preexistentes, privilegios
    heredados, privilegios directos a usuarios y atributos
    administrativos.
6.  Las políticas de contraseña, rotación, MFA del entorno de
    administración, alertas y respuesta ante credenciales comprometidas
    deben definirse y verificarse en el entorno operativo.

## Criterio de aceptación

La configuración no debe declararse validada únicamente porque los
scripts finalicen sin errores. Como mínimo, conservar evidencia de:

-   Base de datos y usuario con los que se ejecutó cada revisión.
-   Resultado de la matriz de permisos esperados frente a los efectivos.
-   Membresías y atributos administrativos revisados.
-   Pruebas positivas y negativas por rol.
-   Estado de RLS y sus políticas, si se implementa aislamiento por
    filas.
-   Evidencia externa de cambios administrativos, si se habilita ese
    control.
-   Incidencias detectadas, responsables y acciones correctivas.

## Archivos de referencia

-   `docs/manual-seguridad.md` --- procedimiento operativo y
    metodología.
-   `docs/decisiones-seguridad.md` --- decisiones de diseño.
-   `docs/diccionario de permisos de usuarios.md` --- detalle de
    permisos por función.
-   `scripts/` --- implementación y auditoría SQL.
