-- ============================================================
-- 05_permisos_secuencias.sql
-- Proyecto: ENVIO-SEGURO
-- PostgreSQL 17
--
-- Objetivo:
--   Auditar las secuencias del esquema public y determinar si
--   requieren permisos explicitos para las cuentas funcionales.
--
-- IMPORTANTE:
--   El esquema actual utiliza columnas GENERATED AS IDENTITY.
--   PostgreSQL administra sus secuencias implicitas; la insercion
--   normal que omite el ID no requiere conceder USAGE al usuario.
--   Por seguridad, este script NO concede permisos masivos.
--
-- Este script es de solo lectura. No modifica privilegios ni datos.
-- Ejecutar desde psql despues de: \encoding UTF8
-- ============================================================

\echo
\echo '============================================================'
\echo '  05 - AUDITORIA DE SECUENCIAS'
\echo '============================================================'

-- 1. Inventario de secuencias del esquema public.
SELECT
    n.nspname AS esquema,
    s.relname AS secuencia,
    pg_get_userbyid(s.relowner) AS propietario,
    CASE
      WHEN EXISTS (
          SELECT 1
          FROM information_schema.columns c
          WHERE c.table_schema = n.nspname
            AND pg_get_serial_sequence(
                  format('%I.%I', c.table_schema, c.table_name),
                  c.column_name
                ) = format('%I.%I', n.nspname, s.relname)
      ) THEN 'ASOCIADA A COLUMNA IDENTITY/SERIAL'
      ELSE 'REVISAR ASOCIACION'
    END AS asociacion
FROM pg_class s
JOIN pg_namespace n ON n.oid = s.relnamespace
WHERE s.relkind = 'S'
  AND n.nspname = 'public'
ORDER BY s.relname;

\echo
\echo '2. COLUMNAS IDENTITY Y SUS SECUENCIAS'
\echo '-------------------------------------'

SELECT
    c.table_schema AS esquema,
    c.table_name AS tabla,
    c.column_name AS columna,
    c.is_identity AS es_identity,
    c.identity_generation AS generacion,
    pg_get_serial_sequence(
        format('%I.%I', c.table_schema, c.table_name),
        c.column_name
    ) AS secuencia_asociada
FROM information_schema.columns c
WHERE c.table_schema = 'public'
  AND c.is_identity = 'YES'
ORDER BY c.table_name, c.ordinal_position;

\echo
\echo '3. PRIVILEGIOS EXPLICITOS DE SECUENCIAS POR CUENTA'
\echo '-------------------------------------------------'

WITH usuarios(usuario) AS (
    VALUES
      ('usr_gerencia_01'::name),
      ('usr_encargado_sucursal_01'::name),
      ('usr_recepcionista_01'::name),
      ('usr_repartidor_01'::name),
      ('usr_contabilidad_01'::name),
      ('usr_auditor_01'::name),
      ('usr_backup_01'::name),
      ('usr_dba_01'::name)
),
secuencias AS (
    SELECT
        n.nspname AS esquema,
        s.relname AS secuencia,
        format('%I.%I', n.nspname, s.relname) AS nombre_calificado
    FROM pg_class s
    JOIN pg_namespace n ON n.oid = s.relnamespace
    WHERE s.relkind = 'S'
      AND n.nspname = 'public'
)
SELECT
    u.usuario,
    s.secuencia,
    has_sequence_privilege(u.usuario, s.nombre_calificado, 'USAGE') AS tiene_usage,
    has_sequence_privilege(u.usuario, s.nombre_calificado, 'SELECT') AS tiene_select,
    has_sequence_privilege(u.usuario, s.nombre_calificado, 'UPDATE') AS tiene_update
FROM usuarios u
CROSS JOIN secuencias s
WHERE EXISTS (
    SELECT 1 FROM pg_roles r WHERE r.rolname = u.usuario
)
ORDER BY u.usuario, s.secuencia;

\echo
\echo '4. DIAGNOSTICO DE NECESIDAD DE GRANTS'
\echo '-------------------------------------'
\echo 'Las columnas IDENTITY generan valores automaticamente al insertar sin especificar el ID.'
\echo 'No se debe conceder USAGE en bloque solo para permitir esos INSERT.'

SELECT
    count(*) FILTER (WHERE c.is_identity = 'YES') AS columnas_identity,
    count(*) FILTER (
        WHERE c.is_identity = 'NO'
          AND c.column_default LIKE 'nextval(%'
    ) AS columnas_serial_o_nextval,
    CASE
      WHEN count(*) FILTER (WHERE c.is_identity = 'YES') > 0
       AND count(*) FILTER (
           WHERE c.is_identity = 'NO'
             AND c.column_default LIKE 'nextval(%'
       ) = 0
      THEN 'NO SE REQUIERE GRANT MASIVO PARA INSERT IDENTITY'
      ELSE 'REVISAR SECUENCIAS SERIAL O DEFAULT nextval()'
    END AS recomendacion
FROM information_schema.columns c
WHERE c.table_schema = 'public';

\echo
\echo '5. SECUENCIAS NO ASOCIADAS A COLUMNAS IDENTITY'
\echo '----------------------------------------------'
SELECT
    n.nspname AS esquema,
    s.relname AS secuencia,
    pg_get_userbyid(s.relowner) AS propietario
FROM pg_class s
JOIN pg_namespace n ON n.oid = s.relnamespace
WHERE s.relkind = 'S'
  AND n.nspname = 'public'
  AND NOT EXISTS (
      SELECT 1
      FROM information_schema.columns c
      WHERE c.table_schema = n.nspname
        AND pg_get_serial_sequence(
              format('%I.%I', c.table_schema, c.table_name),
              c.column_name
            ) = format('%I.%I', n.nspname, s.relname)
  )
ORDER BY s.relname;

\echo
\echo 'FIN DE LA AUDITORIA DE SECUENCIAS. No se modificaron permisos.'
