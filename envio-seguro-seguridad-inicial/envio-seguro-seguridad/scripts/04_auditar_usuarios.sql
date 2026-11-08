/*
===============================================================================
PROYECTO: ENVIO-SEGURO
ARCHIVO: 04_auditar_usuarios.sql
PROPOSITO:
    Ejecutar en un solo archivo la auditoria descriptiva y la comparacion
    de los privilegios efectivos contra la linea base RBAC del proyecto.

CONTENIDO:
    1. Matriz CRUD efectiva por usuario y tabla.
    2. Resumen cuantitativo CRUD por usuario.
    3. Privilegios efectivos por columna.
    4. Atributos administrativos de las cuentas LOGIN.
    5. Validacion de cuentas y membresias contra la linea base.
    6. Comparacion CRUD esperado vs. real.
    7. Comparacion de UPDATE esperado vs. real por columna.
    8. Resumen de cumplimiento CRUD por usuario.
    9. Resumen de cumplimiento UPDATE por columna.
   10. Resultado global de conformidad.

REQUISITOS:
    - PostgreSQL 17.
    - Ejecutar conectado a la base envio_seguro.
    - Roles y cuentas definidos en los scripts 01, 02 y 03.

IMPORTANTE:
    - La linea base refleja la matriz RBAC definida para este proyecto.
    - UPDATE por columna no equivale a UPDATE sobre toda la tabla.
    - El script no ejecuta GRANT, REVOKE ni modifica objetos permanentes.
    - Crea unicamente tablas TEMPORARY, eliminadas al cerrar la sesion.
    - La auditoria no evalua RLS, secuencias, funciones ni vistas.
===============================================================================
*/

\set ON_ERROR_STOP on
\encoding UTF8

-- ---------------------------------------------------------------------------
-- 0. Validar base de datos y version
-- ---------------------------------------------------------------------------

DO $$
BEGIN
    IF current_database() <> 'envio_seguro' THEN
        RAISE EXCEPTION
            'Base incorrecta: %. Se requiere envio_seguro.',
            current_database();
    END IF;

    IF current_setting('server_version_num')::integer < 170000
       OR current_setting('server_version_num')::integer >= 180000 THEN
        RAISE EXCEPTION 'Este proyecto contempla PostgreSQL 17.';
    END IF;
END
$$;

-- ---------------------------------------------------------------------------
-- 1. MATRIZ CRUD A NIVEL DE TABLA
-- ---------------------------------------------------------------------------
-- TRUE significa que el usuario tiene el privilegio a nivel de tabla.
-- FALSE significa que no lo tiene a ese nivel.
-- Los permisos restringidos a columnas se muestran en la seccion 3.

SELECT
    u.rolname AS usuario,
    m.rolname AS rol_funcional,
    t.tablename AS tabla,

    has_table_privilege(
        u.rolname,
        format('%I.%I', t.schemaname, t.tablename),
        'SELECT'
    ) AS puede_select,

    has_table_privilege(
        u.rolname,
        format('%I.%I', t.schemaname, t.tablename),
        'INSERT'
    ) AS puede_insert,

    has_table_privilege(
        u.rolname,
        format('%I.%I', t.schemaname, t.tablename),
        'UPDATE'
    ) AS puede_update_tabla,

    has_table_privilege(
        u.rolname,
        format('%I.%I', t.schemaname, t.tablename),
        'DELETE'
    ) AS puede_delete

FROM pg_roles AS u
JOIN pg_auth_members AS am
    ON am.member = u.oid
JOIN pg_roles AS m
    ON m.oid = am.roleid
CROSS JOIN pg_tables AS t
WHERE u.rolcanlogin = TRUE
  AND left(m.rolname, 4) = 'rol_'
  AND t.schemaname = 'public'
ORDER BY
    u.rolname,
    t.tablename;

-- ---------------------------------------------------------------------------
-- 2. RESUMEN CRUD A NIVEL DE TABLA POR USUARIO
-- ---------------------------------------------------------------------------
-- Los conteos representan cantidad de tablas con el privilegio indicado.
-- No cuentan permisos concedidos solamente a nivel de columna.

WITH usuarios AS (
    SELECT
        u.oid AS usuario_oid,
        u.rolname AS usuario,
        m.rolname AS rol_funcional
    FROM pg_roles AS u
    JOIN pg_auth_members AS am
        ON am.member = u.oid
    JOIN pg_roles AS m
        ON m.oid = am.roleid
    WHERE u.rolcanlogin = TRUE
      AND left(m.rolname, 4) = 'rol_'
),
conteo AS (
    SELECT
        us.usuario,
        us.rol_funcional,

        COUNT(*) FILTER (
            WHERE has_table_privilege(
                us.usuario_oid,
                format('%I.%I', t.schemaname, t.tablename),
                'SELECT'
            )
        ) AS tablas_select,

        COUNT(*) FILTER (
            WHERE has_table_privilege(
                us.usuario_oid,
                format('%I.%I', t.schemaname, t.tablename),
                'INSERT'
            )
        ) AS tablas_insert,

        COUNT(*) FILTER (
            WHERE has_table_privilege(
                us.usuario_oid,
                format('%I.%I', t.schemaname, t.tablename),
                'UPDATE'
            )
        ) AS tablas_update_completo,

        COUNT(*) FILTER (
            WHERE has_table_privilege(
                us.usuario_oid,
                format('%I.%I', t.schemaname, t.tablename),
                'DELETE'
            )
        ) AS tablas_delete

    FROM usuarios AS us
    CROSS JOIN pg_tables AS t
    WHERE t.schemaname = 'public'
    GROUP BY us.usuario, us.rol_funcional
)
SELECT
    usuario,
    rol_funcional,
    tablas_select,
    tablas_insert,
    tablas_update_completo,
    tablas_delete,
    (
        tablas_select +
        tablas_insert +
        tablas_update_completo +
        tablas_delete
    ) AS total_privilegios_tabla,
    DENSE_RANK() OVER (
        ORDER BY
            tablas_select +
            tablas_insert +
            tablas_update_completo +
            tablas_delete
    ) AS nivel_cuantitativo
FROM conteo
ORDER BY
    total_privilegios_tabla,
    usuario;

-- ---------------------------------------------------------------------------
-- 3. PRIVILEGIOS EFECTIVOS A NIVEL DE COLUMNA
-- ---------------------------------------------------------------------------
-- Esta consulta es especialmente importante para UPDATE restringidos.
-- Ejemplo: el repartidor puede actualizar fecha_llegada y observaciones
-- de asignacion_ruta sin tener UPDATE sobre toda la tabla.

WITH usuarios AS (
    SELECT
        u.oid AS usuario_oid,
        u.rolname AS usuario,
        m.rolname AS rol_funcional
    FROM pg_roles AS u
    JOIN pg_auth_members AS am
        ON am.member = u.oid
    JOIN pg_roles AS m
        ON m.oid = am.roleid
    WHERE u.rolcanlogin = TRUE
      AND left(m.rolname, 4) = 'rol_'
),
columnas AS (
    SELECT
        c.table_schema,
        c.table_name,
        c.column_name
    FROM information_schema.columns AS c
    WHERE c.table_schema = 'public'
)
SELECT
    us.usuario,
    us.rol_funcional,
    col.table_name AS tabla,
    col.column_name AS columna,
    priv.privilegio
FROM usuarios AS us
CROSS JOIN columnas AS col
CROSS JOIN (
    VALUES
        ('SELECT'),
        ('INSERT'),
        ('UPDATE')
) AS priv(privilegio)
WHERE
    CASE priv.privilegio
        WHEN 'SELECT' THEN has_column_privilege(
            us.usuario_oid,
            format('%I.%I', col.table_schema, col.table_name),
            col.column_name,
            'SELECT'
        )
        WHEN 'INSERT' THEN has_column_privilege(
            us.usuario_oid,
            format('%I.%I', col.table_schema, col.table_name),
            col.column_name,
            'INSERT'
        )
        WHEN 'UPDATE' THEN has_column_privilege(
            us.usuario_oid,
            format('%I.%I', col.table_schema, col.table_name),
            col.column_name,
            'UPDATE'
        )
    END
ORDER BY
    us.usuario,
    col.table_name,
    col.column_name,
    priv.privilegio;

-- ---------------------------------------------------------------------------
-- 4. ATRIBUTOS ADMINISTRATIVOS DE LAS CUENTAS LOGIN
-- ---------------------------------------------------------------------------
-- Estos atributos no son privilegios CRUD de tablas. Se auditan por separado.

SELECT
    rolname AS usuario,
    rolsuper AS superusuario,
    rolcreatedb AS puede_crear_bases,
    rolcreaterole AS puede_crear_roles,
    rolreplication AS puede_replicar,
    rolbypassrls AS omite_rls,
    rolcanlogin AS puede_iniciar_sesion
FROM pg_roles
WHERE rolcanlogin = TRUE
ORDER BY
    rolsuper DESC,
    rolcreaterole DESC,
    rolcreatedb DESC,
    rolbypassrls DESC,
    rolname;

-- FIN DEL SCRIPT


-- ---------------------------------------------------------------------------
-- 5. CONSTRUIR LINEA BASE Y VALIDAR CUENTAS / MEMBRESIAS
-- ---------------------------------------------------------------------------
-- La linea base representa la matriz definida en 02_configurar_permisos.sql.
-- Los privilegios se comparan sobre las 20 tablas del esquema public.
-- No se modifican GRANT, REVOKE, datos ni objetos permanentes.

CREATE TEMP TABLE baseline_permisos_tabla AS
WITH matriz(rol, tabla, privilegios) AS (
    VALUES
    -- GERENCIA: consulta de informacion administrativa y operativa.
    ('rol_gerencia', 'agencia', ARRAY['SELECT']),
    ('rol_gerencia', 'sucursal', ARRAY['SELECT']),
    ('rol_gerencia', 'encomienda', ARRAY['SELECT']),
    ('rol_gerencia', 'estado_encomienda', ARRAY['SELECT']),
    ('rol_gerencia', 'guia_envio', ARRAY['SELECT']),
    ('rol_gerencia', 'ruta', ARRAY['SELECT']),
    ('rol_gerencia', 'asignacion_ruta', ARRAY['SELECT']),
    ('rol_gerencia', 'evento_rastreo', ARRAY['SELECT']),
    ('rol_gerencia', 'pago', ARRAY['SELECT']),
    ('rol_gerencia', 'metodo_pago', ARRAY['SELECT']),
    ('rol_gerencia', 'documento_dte', ARRAY['SELECT']),
    ('rol_gerencia', 'tipo_dte', ARRAY['SELECT']),
    ('rol_gerencia', 'estado_dte', ARRAY['SELECT']),
    ('rol_gerencia', 'servicio_tarifa', ARRAY['SELECT']),
    ('rol_gerencia', 'detalle_dte', ARRAY['SELECT']),
    ('rol_gerencia', 'incidencia', ARRAY['SELECT']),
    ('rol_gerencia', 'tipo_incidencia', ARRAY['SELECT']),

    -- ENCARGADO DE SUCURSAL.
    ('rol_encargado_sucursal', 'sucursal', ARRAY['SELECT']),
    ('rol_encargado_sucursal', 'empleado', ARRAY['SELECT']),
    ('rol_encargado_sucursal', 'repartidor', ARRAY['SELECT']),
    ('rol_encargado_sucursal', 'cliente', ARRAY['SELECT']),
    ('rol_encargado_sucursal', 'estado_encomienda', ARRAY['SELECT']),
    ('rol_encargado_sucursal', 'encomienda', ARRAY['SELECT']),
    ('rol_encargado_sucursal', 'guia_envio', ARRAY['SELECT']),
    ('rol_encargado_sucursal', 'ruta', ARRAY['SELECT','INSERT','UPDATE']),
    ('rol_encargado_sucursal', 'asignacion_ruta', ARRAY['SELECT','INSERT','UPDATE']),
    ('rol_encargado_sucursal', 'evento_rastreo', ARRAY['SELECT','INSERT']),
    ('rol_encargado_sucursal', 'tipo_incidencia', ARRAY['SELECT']),
    ('rol_encargado_sucursal', 'incidencia', ARRAY['SELECT','INSERT','UPDATE']),

    -- RECEPCIONISTA.
    ('rol_recepcionista', 'sucursal', ARRAY['SELECT']),
    ('rol_recepcionista', 'cliente', ARRAY['SELECT','INSERT','UPDATE']),
    ('rol_recepcionista', 'estado_encomienda', ARRAY['SELECT']),
    ('rol_recepcionista', 'encomienda', ARRAY['SELECT','INSERT']),
    ('rol_recepcionista', 'guia_envio', ARRAY['SELECT','INSERT']),
    ('rol_recepcionista', 'empleado', ARRAY['SELECT']),
    ('rol_recepcionista', 'metodo_pago', ARRAY['SELECT']),
    ('rol_recepcionista', 'evento_rastreo', ARRAY['INSERT']),
    ('rol_recepcionista', 'pago', ARRAY['INSERT']),

    -- REPARTIDOR.
    ('rol_repartidor', 'sucursal', ARRAY['SELECT']),
    ('rol_repartidor', 'estado_encomienda', ARRAY['SELECT']),
    ('rol_repartidor', 'encomienda', ARRAY['SELECT']),
    ('rol_repartidor', 'ruta', ARRAY['SELECT']),
    ('rol_repartidor', 'asignacion_ruta', ARRAY['SELECT']),
    ('rol_repartidor', 'evento_rastreo', ARRAY['SELECT','INSERT']),
    ('rol_repartidor', 'tipo_incidencia', ARRAY['SELECT']),
    ('rol_repartidor', 'incidencia', ARRAY['INSERT']),

    -- CONTABILIDAD.
    ('rol_contabilidad', 'cliente', ARRAY['SELECT']),
    ('rol_contabilidad', 'encomienda', ARRAY['SELECT']),
    ('rol_contabilidad', 'guia_envio', ARRAY['SELECT']),
    ('rol_contabilidad', 'pago', ARRAY['SELECT','INSERT','UPDATE']),
    ('rol_contabilidad', 'metodo_pago', ARRAY['SELECT']),
    ('rol_contabilidad', 'documento_dte', ARRAY['SELECT','INSERT','UPDATE']),
    ('rol_contabilidad', 'detalle_dte', ARRAY['SELECT','INSERT','UPDATE']),
    ('rol_contabilidad', 'tipo_dte', ARRAY['SELECT']),
    ('rol_contabilidad', 'estado_dte', ARRAY['SELECT']),
    ('rol_contabilidad', 'servicio_tarifa', ARRAY['SELECT'])
),
expandida AS (
    SELECT rol, tabla, unnest(privilegios) AS privilegio
    FROM matriz
)
SELECT rol, tabla, privilegio
FROM expandida;

-- DBA: DML completo sobre las 20 tablas, sin SUPERUSER.
INSERT INTO baseline_permisos_tabla (rol, tabla, privilegio)
SELECT 'rol_dba', t.tabla, p.privilegio
FROM (VALUES
    ('agencia'), ('sucursal'), ('empleado'), ('repartidor'), ('cliente'),
    ('estado_encomienda'), ('encomienda'), ('guia_envio'), ('ruta'),
    ('asignacion_ruta'), ('evento_rastreo'), ('metodo_pago'), ('pago'),
    ('tipo_dte'), ('estado_dte'), ('servicio_tarifa'), ('documento_dte'),
    ('detalle_dte'), ('tipo_incidencia'), ('incidencia')
) AS t(tabla)
CROSS JOIN (VALUES ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE')) AS p(privilegio);

-- Auditor y backup: lectura global de las 20 tablas.
INSERT INTO baseline_permisos_tabla (rol, tabla, privilegio)
SELECT r.rol, t.tabla, 'SELECT'
FROM (VALUES ('rol_auditor'), ('rol_backup')) AS r(rol)
CROSS JOIN (VALUES
    ('agencia'), ('sucursal'), ('empleado'), ('repartidor'), ('cliente'),
    ('estado_encomienda'), ('encomienda'), ('guia_envio'), ('ruta'),
    ('asignacion_ruta'), ('evento_rastreo'), ('metodo_pago'), ('pago'),
    ('tipo_dte'), ('estado_dte'), ('servicio_tarifa'), ('documento_dte'),
    ('detalle_dte'), ('tipo_incidencia'), ('incidencia')
) AS t(tabla);

-- Cuentas LOGIN y su rol funcional esperado.
CREATE TEMP TABLE usuarios_baseline (
    usuario name PRIMARY KEY,
    rol name NOT NULL
);

INSERT INTO usuarios_baseline (usuario, rol) VALUES
('usr_gerencia_01', 'rol_gerencia'),
('usr_encargado_sucursal_01', 'rol_encargado_sucursal'),
('usr_recepcionista_01', 'rol_recepcionista'),
('usr_repartidor_01', 'rol_repartidor'),
('usr_contabilidad_01', 'rol_contabilidad'),
('usr_auditor_01', 'rol_auditor'),
('usr_backup_01', 'rol_backup'),
('usr_dba_01', 'rol_dba');

-- Permisos UPDATE intencionalmente limitados a columnas.
-- No deben confundirse con UPDATE a nivel de tabla.
CREATE TEMP TABLE baseline_permisos_columna (
    rol name NOT NULL,
    tabla name NOT NULL,
    columna name NOT NULL,
    privilegio text NOT NULL
);

INSERT INTO baseline_permisos_columna (rol, tabla, columna, privilegio) VALUES
('rol_encargado_sucursal', 'repartidor', 'activo', 'UPDATE'),
('rol_repartidor', 'asignacion_ruta', 'fecha_llegada', 'UPDATE'),
('rol_repartidor', 'asignacion_ruta', 'observaciones', 'UPDATE');


\echo
\echo '5. VALIDACION DE CUENTAS Y MEMBRESIAS'
\echo '-------------------------------------'

SELECT
    u.usuario,
    u.rol AS rol_esperado,
    CASE WHEN r.rolname IS NULL THEN 'NO EXISTE'
         ELSE 'EXISTE' END AS estado_usuario,
    CASE WHEN r.rolname IS NOT NULL
              AND pg_has_role(u.usuario, u.rol, 'USAGE')
         THEN 'OK'
         ELSE 'REVISAR MEMBRESIA' END AS estado_membresia
FROM usuarios_baseline u
LEFT JOIN pg_roles r ON r.rolname = u.usuario::text
ORDER BY u.usuario;

\echo
\echo '6. COMPARACION CRUD POR USUARIO Y TABLA'
\echo '---------------------------------------'
\echo 'COINCIDE = esperado y real son iguales; FALTANTE = falta un permiso; EXCESO = permiso no previsto.'

WITH tablas AS (
    SELECT c.table_name::name AS tabla
    FROM information_schema.tables c
    WHERE c.table_schema = 'public'
      AND c.table_type = 'BASE TABLE'
),
privilegios AS (
    SELECT unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE']) AS privilegio
),
esperado AS (
    SELECT u.usuario, t.tabla, p.privilegio,
           EXISTS (
               SELECT 1
               FROM baseline_permisos_tabla b
               WHERE b.rol = u.rol
                 AND b.tabla = t.tabla::text
                 AND b.privilegio = p.privilegio
           ) AS esperado
    FROM usuarios_baseline u
    CROSS JOIN tablas t
    CROSS JOIN privilegios p
),
comparacion AS (
    SELECT e.*,
           CASE e.privilegio
             WHEN 'SELECT' THEN has_table_privilege(e.usuario, format('%I.%I','public',e.tabla), 'SELECT')
             WHEN 'INSERT' THEN has_table_privilege(e.usuario, format('%I.%I','public',e.tabla), 'INSERT')
             WHEN 'UPDATE' THEN has_table_privilege(e.usuario, format('%I.%I','public',e.tabla), 'UPDATE')
             WHEN 'DELETE' THEN has_table_privilege(e.usuario, format('%I.%I','public',e.tabla), 'DELETE')
           END AS real
    FROM esperado e
)
SELECT
    usuario,
    tabla,
    privilegio,
    CASE WHEN esperado THEN 'SI' ELSE 'NO' END AS esperado,
    CASE WHEN real THEN 'SI' ELSE 'NO' END AS real,
    CASE
      WHEN esperado = real THEN 'COINCIDE'
      WHEN esperado AND NOT real THEN 'FALTANTE'
      WHEN NOT esperado AND real THEN 'EXCESO'
    END AS estado
FROM comparacion
ORDER BY usuario, tabla,
         CASE privilegio WHEN 'SELECT' THEN 1 WHEN 'INSERT' THEN 2
                         WHEN 'UPDATE' THEN 3 WHEN 'DELETE' THEN 4 END;

\echo
\echo '7. COMPARACION DE UPDATE EN TODAS LAS COLUMNAS'
\echo '-----------------------------------------------'
\echo 'Incluye permisos UPDATE de tabla y permisos UPDATE concedidos a columnas individuales.'

WITH columnas AS (
    SELECT c.table_name::name AS tabla, c.column_name::name AS columna
    FROM information_schema.columns c
    WHERE c.table_schema = 'public'
),
esperado AS (
    SELECT
        u.usuario,
        c.tabla,
        c.columna,
        (
            EXISTS (
                SELECT 1
                FROM baseline_permisos_tabla b
                WHERE b.rol = u.rol
                  AND b.tabla = c.tabla::text
                  AND b.privilegio = 'UPDATE'
            )
            OR EXISTS (
                SELECT 1
                FROM baseline_permisos_columna bc
                WHERE bc.rol = u.rol
                  AND bc.tabla = c.tabla
                  AND bc.columna = c.columna
                  AND bc.privilegio = 'UPDATE'
            )
        ) AS esperado
    FROM usuarios_baseline u
    CROSS JOIN columnas c
),
comparacion AS (
    SELECT e.*,
           has_column_privilege(
               e.usuario,
               format('%I.%I','public',e.tabla),
               e.columna,
               'UPDATE'
           ) AS real
    FROM esperado e
)
SELECT
    usuario,
    tabla,
    columna,
    CASE WHEN esperado THEN 'SI' ELSE 'NO' END AS esperado,
    CASE WHEN real THEN 'SI' ELSE 'NO' END AS real,
    CASE
      WHEN esperado = real THEN 'COINCIDE'
      WHEN esperado AND NOT real THEN 'FALTANTE'
      WHEN NOT esperado AND real THEN 'EXCESO'
    END AS estado
FROM comparacion
WHERE esperado OR real
ORDER BY usuario, tabla, columna;

\echo
\echo '8. RESUMEN DE CUMPLIMIENTO CRUD'
\echo '-------------------------------'
WITH tablas AS (
    SELECT c.table_name::name AS tabla
    FROM information_schema.tables c
    WHERE c.table_schema = 'public'
      AND c.table_type = 'BASE TABLE'
),
privilegios AS (
    SELECT unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE']) AS privilegio
),
esperado AS (
    SELECT u.usuario, u.rol, t.tabla, p.privilegio,
           EXISTS (
               SELECT 1 FROM baseline_permisos_tabla b
               WHERE b.rol = u.rol
                 AND b.tabla = t.tabla::text
                 AND b.privilegio = p.privilegio
           ) AS esperado
    FROM usuarios_baseline u
    CROSS JOIN tablas t
    CROSS JOIN privilegios p
),
comparacion AS (
    SELECT e.*,
           CASE e.privilegio
             WHEN 'SELECT' THEN has_table_privilege(e.usuario, format('%I.%I','public',e.tabla), 'SELECT')
             WHEN 'INSERT' THEN has_table_privilege(e.usuario, format('%I.%I','public',e.tabla), 'INSERT')
             WHEN 'UPDATE' THEN has_table_privilege(e.usuario, format('%I.%I','public',e.tabla), 'UPDATE')
             WHEN 'DELETE' THEN has_table_privilege(e.usuario, format('%I.%I','public',e.tabla), 'DELETE')
           END AS real
    FROM esperado e
)
SELECT
    usuario,
    count(*) FILTER (WHERE esperado) AS permisos_esperados,
    count(*) FILTER (WHERE esperado AND real) AS permisos_correctos,
    count(*) FILTER (WHERE esperado AND NOT real) AS permisos_faltantes,
    count(*) FILTER (WHERE NOT esperado AND real) AS permisos_excesivos,
    CASE
      WHEN count(*) FILTER (WHERE esperado AND NOT real) = 0
       AND count(*) FILTER (WHERE NOT esperado AND real) = 0
      THEN 'CONFORME'
      ELSE 'NO CONFORME'
    END AS resultado
FROM comparacion
GROUP BY usuario
ORDER BY usuario;

\echo
\echo '9. RESUMEN DE UPDATE POR COLUMNA'
\echo '---------------------------------'
WITH columnas AS (
    SELECT c.table_name::name AS tabla, c.column_name::name AS columna
    FROM information_schema.columns c
    WHERE c.table_schema = 'public'
),
comparacion AS (
    SELECT
        u.usuario,
        (
            EXISTS (
                SELECT 1 FROM baseline_permisos_tabla b
                WHERE b.rol = u.rol
                  AND b.tabla = c.tabla::text
                  AND b.privilegio = 'UPDATE'
            )
            OR EXISTS (
                SELECT 1 FROM baseline_permisos_columna bc
                WHERE bc.rol = u.rol
                  AND bc.tabla = c.tabla
                  AND bc.columna = c.columna
                  AND bc.privilegio = 'UPDATE'
            )
        ) AS esperado,
        has_column_privilege(
            u.usuario,
            format('%I.%I','public',c.tabla),
            c.columna,
            'UPDATE'
        ) AS real
    FROM usuarios_baseline u
    CROSS JOIN columnas c
)
SELECT
    usuario,
    count(*) FILTER (WHERE esperado) AS columnas_esperadas,
    count(*) FILTER (WHERE esperado AND real) AS columnas_correctas,
    count(*) FILTER (WHERE esperado AND NOT real) AS columnas_faltantes,
    count(*) FILTER (WHERE NOT esperado AND real) AS columnas_excesivas,
    CASE
      WHEN count(*) FILTER (WHERE esperado AND NOT real) = 0
       AND count(*) FILTER (WHERE NOT esperado AND real) = 0
      THEN 'CONFORME'
      ELSE 'NO CONFORME'
    END AS resultado
FROM comparacion
GROUP BY usuario
ORDER BY usuario;

\echo
\echo '10. ESTADO GLOBAL'
\echo '----------------'
WITH tablas AS (
    SELECT c.table_name::name AS tabla
    FROM information_schema.tables c
    WHERE c.table_schema = 'public'
      AND c.table_type = 'BASE TABLE'
),
privilegios AS (
    SELECT unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE']) AS privilegio
),
esperado AS (
    SELECT u.usuario, u.rol, t.tabla, p.privilegio,
           EXISTS (
               SELECT 1 FROM baseline_permisos_tabla b
               WHERE b.rol = u.rol
                 AND b.tabla = t.tabla::text
                 AND b.privilegio = p.privilegio
           ) AS esperado
    FROM usuarios_baseline u
    CROSS JOIN tablas t
    CROSS JOIN privilegios p
),
comparacion AS (
    SELECT e.*,
           CASE e.privilegio
             WHEN 'SELECT' THEN has_table_privilege(e.usuario, format('%I.%I','public',e.tabla), 'SELECT')
             WHEN 'INSERT' THEN has_table_privilege(e.usuario, format('%I.%I','public',e.tabla), 'INSERT')
             WHEN 'UPDATE' THEN has_table_privilege(e.usuario, format('%I.%I','public',e.tabla), 'UPDATE')
             WHEN 'DELETE' THEN has_table_privilege(e.usuario, format('%I.%I','public',e.tabla), 'DELETE')
           END AS real
    FROM esperado e
),
totales AS (
    SELECT
      count(*) FILTER (WHERE esperado AND NOT real) AS faltantes,
      count(*) FILTER (WHERE NOT esperado AND real) AS excesivos
    FROM comparacion
)
SELECT
    faltantes,
    excesivos,
    CASE WHEN faltantes = 0 AND excesivos = 0
         THEN 'BASELINE CRUD CONFORME'
         ELSE 'BASELINE CRUD NO CONFORME'
    END AS resultado
FROM totales;

\echo
\echo 'Nota: se comparan privilegios CRUD de tabla y UPDATE efectivo por columna.'
\echo 'No evalua RLS, privilegios de secuencias, funciones ni vistas.'


\echo
\echo 'FIN DE LA AUDITORIA COMPARATIVA.'
\echo 'No se modificaron usuarios, permisos, datos ni objetos permanentes.'
