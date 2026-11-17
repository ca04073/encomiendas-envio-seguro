# Manual técnico de seguridad --- ENVÍO-SEGURO

## 1. Propósito

Este manual describe cómo preparar, ejecutar y revisar los controles de
seguridad de la base de datos ENVÍO-SEGURO en PostgreSQL 17. Su
propósito es que la configuración sea repetible, verificable y
documentada, y que las actividades de auditoría no se confundan con las
actividades de administración.

El diseño utiliza control de acceso basado en roles (RBAC), privilegio
mínimo, separación de funciones y consultas de auditoría sobre los
catálogos de PostgreSQL.

## 2. Principios de seguridad

### 2.1 Identidad individual

Cada persona o proceso debe autenticarse con una cuenta identificable.
Las cuentas compartidas dificultan atribuir acciones a un responsable.

### 2.2 Roles grupales

Los roles funcionales `rol_*` son roles `NOLOGIN`. Se asignan a cuentas
`LOGIN` individuales. Los privilegios se administran preferentemente en
los roles grupales y no mediante concesiones dispersas a cada usuario.

### 2.3 Mínimo privilegio

Cada rol debe recibir solo los permisos necesarios para su función. No
se debe conceder superusuario para resolver problemas de permisos de una
aplicación.

### 2.4 Separación de funciones

La administración de la base de datos, la auditoría y la custodia de
credenciales deben ser responsabilidades diferenciadas cuando la
operación lo permita. Esta separación reduce la posibilidad de que una
misma cuenta cambie controles y oculte la evidencia.

### 2.5 Auditoría independiente

Los resultados de auditoría deben conservarse fuera del alcance de
modificación de la cuenta auditada. Los registros locales de PostgreSQL
son útiles, pero un administrador con control suficiente del servidor
puede alterarlos.

## 3. Componentes del directorio

  -------------------------------------------------------------------------
  Archivo                               Propósito
  ------------------------------------- -----------------------------------
  `00_verificar_entorno.sql`            Comprobaciones iniciales del
                                        entorno y conexión.

  `01_crear_roles.sql`                  Creación de roles grupales.

  `02_configurar_permisos.sql`          Aplicación de la matriz CRUD y
                                        privilegios por rol.

  `03_crear_usuarios.sql`               Creación de cuentas LOGIN y
                                        asignación de roles.

  `04_auditar_usuarios.sql`             Revisión de usuarios, membresías y
                                        privilegios efectivos frente a la
                                        línea base.

  `05_permisos_secuencias.sql`          Inspección de privilegios de
                                        secuencias e identidades.

  `06_crear_estructura_seguridad.sql`   Creación de objetos auxiliares en
                                        el esquema `seguridad`.

  `07_probar_permisos_roles.sql`        Pruebas de permisos de roles según
                                        los casos incluidos en el script.

  `08_auditoria_final_seguridad.sql`    Auditoría final según las
                                        comprobaciones implementadas en el
                                        archivo.
  -------------------------------------------------------------------------

La descripción es funcional y debe contrastarse con el contenido vigente
de cada script antes de modificarlo. Los nombres y números de archivo no
sustituyen la revisión de dependencias SQL.

## 4. Preparación del entorno

1.  Confirmar que PostgreSQL 17 está disponible.
2.  Crear o seleccionar la base de datos de destino.
3.  Conectarse explícitamente a esa base de datos.
4.  Confirmar la conexión:

``` sql
SELECT current_database() AS base_actual,
       current_user AS usuario_actual,
       session_user AS usuario_sesion,
       version();
```

5.  Verificar que el esquema y las tablas esperadas existen antes de
    ejecutar scripts que dependan de ellos.
6.  Realizar un respaldo previo antes de aplicar cambios de roles,
    privilegios o estructuras.

**Importante:** `\i` solo ejecuta un archivo. No selecciona ni cambia la
base de datos. Si se ejecuta conectado a otra base, el script se
aplicará a esa otra base, sujeto a sus sentencias y permisos.

## 5. Secuencia de despliegue

La secuencia general recomendada es:

1.  `00_verificar_entorno.sql`
2.  `01_crear_roles.sql`
3.  `02_configurar_permisos.sql`
4.  `03_crear_usuarios.sql`
5.  Establecer contraseñas individuales.
6.  `05_permisos_secuencias.sql`
7.  `06_crear_estructura_seguridad.sql`
8.  Completar los mapeos de usuarios a sucursales y repartidores, si
    forman parte del despliegue.
9.  `04_auditar_usuarios.sql`
10. `07_probar_permisos_roles.sql`
11. `08_auditoria_final_seguridad.sql`

Los scripts `04`, `05`, `07` y `08` son principalmente de inspección o
validación según su diseño; los scripts `01`, `02`, `03` y `06` realizan
cambios de configuración. Revisar siempre el contenido actual antes de
ejecutarlos.

### 5.1 Ejemplo en Windows con `psql`

Desde la terminal:

``` text
psql -U postgres -d envio_seguro
```

Dentro de `psql`:

``` text
\i C:/Users/usuario/ruta/proyecto/scripts/00_verificar_entorno.sql
\i C:/Users/usuario/ruta/proyecto/scripts/01_crear_roles.sql
```

Continuar con los demás archivos en el orden definido. Sustituir la ruta
de ejemplo por la ubicación real del repositorio.

También se puede ejecutar desde la terminal:

``` text
psql -U postgres -d envio_seguro -f "C:/Users/usuario/ruta/proyecto/scripts/01_crear_roles.sql"
```

## 6. Gestión segura de contraseñas

El script de creación de usuarios no debe contener contraseñas en texto
claro. Después de crear las cuentas, asignar cada contraseña
interactivamente:

``` text
\password usr_dba_01
\password usr_gerencia_01
\password usr_encargado_sucursal_01
\password usr_recepcionista_01
\password usr_repartidor_01
\password usr_contabilidad_01
\password usr_auditor_01
\password usr_backup_01
```

Recomendaciones:

-   Usar contraseñas únicas, largas y aleatorias.
-   No compartirlas entre usuarios ni ambientes.
-   No almacenarlas en scripts, `.env` versionados, capturas o
    documentos del repositorio.
-   Guardarlas en un gestor de contraseñas con control de acceso.
-   Limitar el acceso a las credenciales administrativas.
-   Cambiar las credenciales cuando exista sospecha de exposición,
    salida de personal o incumplimiento de custodia.
-   Evitar utilizar `postgres` o un superusuario para las tareas
    diarias.
-   Revisar la política de autenticación del servidor y aplicar
    controles adicionales en el entorno de administración cuando estén
    disponibles.

La rotación periódica debe definirse según la política institucional y
el riesgo. Una rotación mal coordinada puede interrumpir servicios; debe
existir un procedimiento de cambio y verificación.

## 7. Cómo se aíslan las auditorías

El aislamiento de una auditoría consiste en limitar su capacidad de
alterar el sistema que está examinando y en separar sus evidencias de
las cuentas auditadas.

### 7.1 Cuenta de auditoría

Ejecutar las comprobaciones con una cuenta que tenga los permisos de
lectura necesarios para consultar los catálogos y objetos evaluados,
pero que no tenga `SUPERUSER`, `CREATEROLE`, `CREATEDB` ni privilegios
de escritura innecesarios.

No asumir que `rol_auditor` puede consultar automáticamente todos los
metadatos requeridos: verificar los resultados y conceder solo el acceso
de lectura estrictamente necesario.

### 7.2 Transacción de solo lectura

Para consultas compatibles, puede utilizarse:

``` sql
BEGIN TRANSACTION READ ONLY;

SELECT current_database(), current_user, session_user;

-- Ejecutar aquí consultas de inspección compatibles.

COMMIT;
```

Una transacción `READ ONLY` impide las operaciones de escritura que
PostgreSQL no permite dentro de ese modo. No convierte un script
arbitrario en seguro ni sustituye la revisión de sus sentencias. Si el
script crea tablas temporales u otros objetos, comprobar la
compatibilidad con el modo de transacción y la versión de PostgreSQL
antes de envolverlo.

### 7.3 Tablas temporales

Una tabla `TEMP` existe en la sesión y se elimina al finalizarla (o
según su cláusula `ON COMMIT`). Es útil para almacenar resultados
intermedios de comparaciones sin crear tablas permanentes en el esquema
de negocio.

Sin embargo: - Una tabla temporal no hace que todas las demás sentencias
sean de solo lectura. - Debe verificarse que las consultas no actualicen
objetos permanentes. - Las tablas temporales pueden contener información
sensible; no deben compartirse sin revisar su contenido.

### 7.4 Catálogos de PostgreSQL

Las auditorías pueden consultar catálogos y vistas como `pg_roles`,
`pg_auth_members`, `information_schema.table_privileges`,
`information_schema.column_privileges`, `pg_class`, `pg_namespace` y
`pg_policy`, según el objetivo.

La visibilidad de metadatos puede variar según el usuario y los
privilegios. Un resultado vacío no siempre demuestra que un objeto o
permiso no exista; puede indicar falta de visibilidad. Interpretar cada
consulta según su alcance.

### 7.5 Comparación contra la línea base

La auditoría compara la configuración observada con la matriz RBAC
esperada. Se deben revisar:

-   Privilegios de tabla: `SELECT`, `INSERT`, `UPDATE`, `DELETE`.
-   Privilegios por columna, especialmente `UPDATE`.
-   Membresías de roles y herencia de privilegios.
-   Privilegios concedidos directamente a usuarios.
-   Atributos administrativos de las cuentas.
-   Privilegios de secuencias y comportamiento de columnas `IDENTITY`.
-   Permisos de esquema, funciones y otros objetos cuando estén dentro
    del alcance.

La auditoría debe reportar diferencias y no corregirlas automáticamente.
La remediación se realiza mediante un cambio revisado y autorizado,
seguido de una nueva auditoría.

## 8. Protección de credenciales y cambios administrativos

### 8.1 Riesgo

Una cuenta con capacidad de administrar roles puede cambiar privilegios,
crear usuarios o conceder membresías. Si también puede modificar o
eliminar la única copia de los registros de auditoría, puede dificultar
la detección de sus propias acciones.

### 8.2 Controles recomendados

-   Restringir quién puede usar cuentas administrativas.
-   No compartir cuentas DBA.
-   Separar la custodia de credenciales de la operación diaria.
-   Revisar periódicamente las membresías y atributos de roles.
-   Registrar cambios de autenticación, roles, membresías, `GRANT` y
    `REVOKE`, cambios de políticas RLS y DDL relevante.
-   Configurar el registro de actividad de PostgreSQL y evaluar
    `pgAudit` según los requisitos del entorno.
-   Enviar los registros a un servidor o servicio externo con controles
    de acceso y retención independientes.
-   Alertar sobre cambios administrativos inesperados.
-   Proteger las copias de seguridad y probar su restauración.

Los registros de PostgreSQL y `pgAudit` requieren configuración y
validación específicas. La disponibilidad de eventos, el volumen
generado y la protección de archivos dependen de la configuración del
servidor. No afirmar que estos controles están activos hasta
verificarlos.

## 9. Estructura auxiliar y seguridad por filas

El script `06_crear_estructura_seguridad.sql` prepara el esquema
`seguridad`, tablas de asociación como `usuario_sucursal` y
`usuario_repartidor`, y funciones auxiliares para evaluar relaciones de
usuario con sucursales, repartidores y encomiendas.

Esto es una base para implementar control de acceso por filas (RLS),
pero no demuestra que RLS esté activo.

Para considerar implementado el aislamiento por sucursal o repartidor,
todavía se debe:

1.  Definir qué tablas requieren aislamiento por fila.
2.  Completar y validar los registros de asociación usuario-sucursal y
    usuario-repartidor.
3.  Diseñar políticas `CREATE POLICY` coherentes con cada operación.
4.  Activar `ENABLE ROW LEVEL SECURITY` en las tablas aplicables.
5.  Evaluar `FORCE ROW LEVEL SECURITY` según el modelo de
    administración.
6.  Probar consultas y modificaciones con cada usuario real, no solo con
    el propietario de las tablas.
7.  Verificar el comportamiento de superusuarios, propietarios y roles
    con `BYPASSRLS`.
8.  Documentar excepciones y procesos autorizados.

Hasta completar estas tareas y ejecutar pruebas negativas y positivas,
RLS debe registrarse como **pendiente de implementación/validación**.

## 10. Procedimiento de auditoría periódica

1.  Abrir una sesión nueva de `psql`.
2.  Conectarse a la base de datos correcta.
3.  Registrar fecha, base de datos, usuario y versión.
4.  Ejecutar `04_auditar_usuarios.sql`.
5.  Ejecutar `05_permisos_secuencias.sql`.
6.  Ejecutar `07_probar_permisos_roles.sql`.
7.  Ejecutar `08_auditoria_final_seguridad.sql`.
8.  Guardar la salida completa y el código de terminación de cada
    ejecución.
9.  Comparar diferencias contra la última auditoría aprobada.
10. Abrir una incidencia para cada desviación.
11. Autorizar y aplicar las correcciones mediante un cambio controlado.
12. Repetir las auditorías y conservar ambas evidencias: antes y
    después.

No ejecutar pruebas potencialmente destructivas en producción. Si una
prueba requiere comprobar denegaciones o escrituras, preferir una base
de pruebas representativa y cuentas de prueba.

## 11. Respuesta ante sospecha de credenciales comprometidas

1.  Activar el procedimiento institucional de incidentes.
2.  Identificar las cuentas y sistemas potencialmente afectados.
3.  Revocar o rotar las credenciales comprometidas de forma controlada.
4.  Revisar roles, membresías, atributos administrativos, privilegios
    directos y políticas.
5.  Comparar la configuración actual con una línea base confiable.
6.  Preservar registros y evidencias externas antes de realizar tareas
    que puedan sobrescribirlos.
7.  Revisar actividad desde el último momento confiable.
8.  Restaurar la configuración autorizada mediante scripts revisados.
9.  Ejecutar nuevamente las pruebas y auditorías.
10. Documentar alcance, cronología, causa, acciones y medidas
    preventivas.

La recuperación debe coordinarse para no bloquear cuentas de servicio
esenciales ni destruir evidencia.

## 12. Criterios de validación

La seguridad no se considera validada solo porque los scripts terminen
sin errores. La revisión debe confirmar:

-   Los usuarios existen y tienen las membresías previstas.
-   No existen membresías adicionales no autorizadas.
-   Los atributos administrativos corresponden a la política.
-   Los privilegios efectivos coinciden con la matriz aprobada.
-   Las operaciones permitidas funcionan.
-   Las operaciones prohibidas son rechazadas.
-   Los permisos de secuencias y columnas de identidad son correctos.
-   Las políticas RLS están activas y probadas, si se requiere
    aislamiento por filas.
-   Los cambios administrativos generan evidencia protegida
    externamente, si ese control está habilitado.

## 13. Registro de estado conocido del proyecto

Según el estado de trabajo documentado:

-   Se definieron roles funcionales y cuentas individuales.
-   Se configuró una matriz de permisos por rol.
-   Se crearon estructuras auxiliares de seguridad y funciones
    `SECURITY DEFINER`.
-   Los scripts `07_probar_permisos_roles.sql` y
    `08_auditoria_final_seguridad.sql` se ejecutaron sin errores de
    ejecución.
-   La ejecución sin errores no constituye una aprobación de todos los
    resultados.
-   La implementación completa de RLS, la carga de mapeos y las pruebas
    de aislamiento por fila deben verificarse por separado.
-   La custodia independiente de credenciales y el envío externo de
    registros deben implementarse y probarse antes de afirmar que existe
    auditoría independiente resistente a la manipulación.

## 14. Mantenimiento del manual

Actualizar este documento cuando cambien: - La matriz RBAC o los nombres
de roles. - Las cuentas LOGIN y sus membresías. - Las tablas o columnas
protegidas. - Las políticas RLS y funciones del esquema `seguridad`. -
Los scripts de despliegue o auditoría. - La plataforma de registro,
respaldo o custodia de credenciales.

Toda modificación de seguridad debe incluir revisión, aprobación, prueba
en un entorno controlado y evidencia de auditoría posterior.
