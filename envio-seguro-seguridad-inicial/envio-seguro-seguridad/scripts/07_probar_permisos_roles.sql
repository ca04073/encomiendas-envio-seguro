\set ON_ERROR_STOP on
\encoding UTF8

/*
===============================================================================
PROYECTO: ENVIO-SEGURO
ARCHIVO: 07_probar_permisos_roles.sql
MOTOR: PostgreSQL 17 | psql
PROPOSITO:
    Comprobar roles, cuentas, membresias, privilegios CRUD efectivos,
    permisos UPDATE por columna, secuencias, funciones y estado RLS.
SEGURIDAD:
    Solo lectura. No ejecuta INSERT/UPDATE/DELETE ni cambia ACL, roles,
    politicas o datos. Las comprobaciones de privilegios no sustituyen una
    prueba de sesion autenticada como cada usuario.
===============================================================================
*/

\echo '============================================================'
\echo '07 - PRUEBAS DE PERMISOS Y ROLES'
\echo '============================================================'

DO $validar$
BEGIN
    IF current_database() <> 'envio_seguro' THEN
        RAISE EXCEPTION 'Base incorrecta: se esperaba envio_seguro; actual: %',
            current_database();
    END IF;
    IF current_setting('server_version_num')::integer / 10000 <> 17 THEN
        RAISE EXCEPTION 'Se requiere PostgreSQL 17.';
    END IF;
END
$validar$;

-- 1. Existencia y atributos de los ocho roles grupales.
WITH esperados(rol) AS (
    VALUES ('rol_dba'::name), ('rol_gerencia'), ('rol_encargado_sucursal'),
           ('rol_recepcionista'), ('rol_repartidor'), ('rol_contabilidad'),
           ('rol_auditor'), ('rol_backup')
)
SELECT e.rol,
       (r.oid IS NOT NULL) AS existe,
       COALESCE(NOT r.rolcanlogin, FALSE) AS no_login,
       COALESCE(NOT r.rolsuper AND NOT r.rolcreatedb
                AND NOT r.rolcreaterole AND NOT r.rolreplication
                AND NOT r.rolbypassrls, FALSE) AS atributos_restringidos,
       CASE WHEN r.oid IS NULL THEN 'FALTA'
            WHEN r.rolcanlogin OR r.rolsuper OR r.rolcreatedb
              OR r.rolcreaterole OR r.rolreplication OR r.rolbypassrls
            THEN 'REVISAR'
            ELSE 'OK' END AS resultado
FROM esperados e
LEFT JOIN pg_roles r ON r.rolname = e.rol
ORDER BY e.rol;

-- 2. Existencia de cuentas LOGIN y membresia funcional esperada.
WITH esperados(usuario, rol) AS (
    VALUES
    ('usr_gerencia_01'::name, 'rol_gerencia'::name),
    ('usr_encargado_sucursal_01', 'rol_encargado_sucursal'),
    ('usr_recepcionista_01', 'rol_recepcionista'),
    ('usr_repartidor_01', 'rol_repartidor'),
    ('usr_contabilidad_01', 'rol_contabilidad'),
    ('usr_auditor_01', 'rol_auditor'),
    ('usr_backup_01', 'rol_backup'),
    ('usr_dba_01', 'rol_dba')
)
SELECT e.usuario, e.rol AS rol_esperado,
       COALESCE(u.rolcanlogin, FALSE) AS puede_login,
       COALESCE(pg_has_role(e.usuario, e.rol, 'USAGE'), FALSE) AS membresia_efectiva,
       CASE WHEN u.oid IS NULL THEN 'USUARIO FALTANTE'
            WHEN NOT u.rolcanlogin THEN 'LOGIN DESHABILITADO'
            WHEN NOT pg_has_role(e.usuario, e.rol, 'USAGE') THEN 'MEMBRESIA FALTANTE'
            ELSE 'OK' END AS resultado
FROM esperados e
LEFT JOIN pg_roles u ON u.rolname = e.usuario
ORDER BY e.usuario;

-- 3. Pruebas negativas/positivas CRUD por usuario.
-- La matriz esperada refleja 02_configurar_permisos.sql.
WITH usuarios(usuario, rol) AS (
    VALUES
    ('usr_gerencia_01'::name, 'rol_gerencia'::name),
    ('usr_encargado_sucursal_01', 'rol_encargado_sucursal'),
    ('usr_recepcionista_01', 'rol_recepcionista'),
    ('usr_repartidor_01', 'rol_repartidor'),
    ('usr_contabilidad_01', 'rol_contabilidad'),
    ('usr_auditor_01', 'rol_auditor'),
    ('usr_backup_01', 'rol_backup'),
    ('usr_dba_01', 'rol_dba')
),
matriz(rol, tabla, privilegio) AS (
    VALUES
    ('rol_gerencia','agencia','SELECT'), ('rol_gerencia','sucursal','SELECT'),
    ('rol_gerencia','encomienda','SELECT'), ('rol_gerencia','estado_encomienda','SELECT'),
    ('rol_gerencia','guia_envio','SELECT'), ('rol_gerencia','ruta','SELECT'),
    ('rol_gerencia','asignacion_ruta','SELECT'), ('rol_gerencia','evento_rastreo','SELECT'),
    ('rol_gerencia','pago','SELECT'), ('rol_gerencia','metodo_pago','SELECT'),
    ('rol_gerencia','documento_dte','SELECT'), ('rol_gerencia','tipo_dte','SELECT'),
    ('rol_gerencia','estado_dte','SELECT'), ('rol_gerencia','servicio_tarifa','SELECT'),
    ('rol_gerencia','detalle_dte','SELECT'), ('rol_gerencia','incidencia','SELECT'),
    ('rol_gerencia','tipo_incidencia','SELECT'),
    ('rol_encargado_sucursal','sucursal','SELECT'), ('rol_encargado_sucursal','empleado','SELECT'),
    ('rol_encargado_sucursal','repartidor','SELECT'), ('rol_encargado_sucursal','cliente','SELECT'),
    ('rol_encargado_sucursal','estado_encomienda','SELECT'), ('rol_encargado_sucursal','encomienda','SELECT'),
    ('rol_encargado_sucursal','guia_envio','SELECT'), ('rol_encargado_sucursal','ruta','SELECT'),
    ('rol_encargado_sucursal','ruta','INSERT'), ('rol_encargado_sucursal','ruta','UPDATE'),
    ('rol_encargado_sucursal','asignacion_ruta','SELECT'), ('rol_encargado_sucursal','asignacion_ruta','INSERT'),
    ('rol_encargado_sucursal','asignacion_ruta','UPDATE'), ('rol_encargado_sucursal','evento_rastreo','SELECT'),
    ('rol_encargado_sucursal','evento_rastreo','INSERT'), ('rol_encargado_sucursal','tipo_incidencia','SELECT'),
    ('rol_encargado_sucursal','incidencia','SELECT'), ('rol_encargado_sucursal','incidencia','INSERT'),
    ('rol_encargado_sucursal','incidencia','UPDATE'),
    ('rol_recepcionista','sucursal','SELECT'), ('rol_recepcionista','cliente','SELECT'),
    ('rol_recepcionista','cliente','INSERT'), ('rol_recepcionista','cliente','UPDATE'),
    ('rol_recepcionista','estado_encomienda','SELECT'), ('rol_recepcionista','encomienda','SELECT'),
    ('rol_recepcionista','encomienda','INSERT'), ('rol_recepcionista','guia_envio','SELECT'),
    ('rol_recepcionista','guia_envio','INSERT'), ('rol_recepcionista','empleado','SELECT'),
    ('rol_recepcionista','metodo_pago','SELECT'), ('rol_recepcionista','evento_rastreo','INSERT'),
    ('rol_recepcionista','pago','INSERT'),
    ('rol_repartidor','sucursal','SELECT'), ('rol_repartidor','estado_encomienda','SELECT'),
    ('rol_repartidor','encomienda','SELECT'), ('rol_repartidor','ruta','SELECT'),
    ('rol_repartidor','asignacion_ruta','SELECT'), ('rol_repartidor','evento_rastreo','SELECT'),
    ('rol_repartidor','evento_rastreo','INSERT'), ('rol_repartidor','tipo_incidencia','SELECT'),
    ('rol_repartidor','incidencia','INSERT'),
    ('rol_contabilidad','cliente','SELECT'), ('rol_contabilidad','encomienda','SELECT'),
    ('rol_contabilidad','guia_envio','SELECT'), ('rol_contabilidad','pago','SELECT'),
    ('rol_contabilidad','pago','INSERT'), ('rol_contabilidad','pago','UPDATE'),
    ('rol_contabilidad','metodo_pago','SELECT'), ('rol_contabilidad','documento_dte','SELECT'),
    ('rol_contabilidad','documento_dte','INSERT'), ('rol_contabilidad','documento_dte','UPDATE'),
    ('rol_contabilidad','detalle_dte','SELECT'), ('rol_contabilidad','detalle_dte','INSERT'),
    ('rol_contabilidad','detalle_dte','UPDATE'), ('rol_contabilidad','tipo_dte','SELECT'),
    ('rol_contabilidad','estado_dte','SELECT'), ('rol_contabilidad','servicio_tarifa','SELECT')
),
tablas AS (
    SELECT c.relname::text AS tabla
    FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relkind IN ('r','p')
),
privs(privilegio) AS (VALUES ('SELECT'),('INSERT'),('UPDATE'),('DELETE')),
esperado AS (
    SELECT u.usuario, u.rol, t.tabla, p.privilegio,
           (m.rol IS NOT NULL) AS esperado
    FROM usuarios u CROSS JOIN tablas t CROSS JOIN privs p
    LEFT JOIN matriz m ON m.rol=u.rol::text AND m.tabla=t.tabla
                      AND m.privilegio=p.privilegio
),
real AS (
    SELECT e.*,
       CASE e.privilegio
         WHEN 'SELECT' THEN has_table_privilege(e.usuario, format('%I.%I','public',e.tabla), 'SELECT')
         WHEN 'INSERT' THEN has_table_privilege(e.usuario, format('%I.%I','public',e.tabla), 'INSERT')
         WHEN 'UPDATE' THEN has_table_privilege(e.usuario, format('%I.%I','public',e.tabla), 'UPDATE')
         WHEN 'DELETE' THEN has_table_privilege(e.usuario, format('%I.%I','public',e.tabla), 'DELETE')
       END AS concedido
    FROM esperado e
)
SELECT usuario, tabla, privilegio,
       CASE WHEN esperado THEN 'PERMITIR' ELSE 'DENEGAR' END AS esperado,
       CASE WHEN concedido THEN 'CONCEDIDO' ELSE 'NO CONCEDIDO' END AS real,
       CASE WHEN esperado=concedido THEN 'OK' ELSE 'REVISAR' END AS resultado
FROM real
WHERE esperado <> concedido
ORDER BY usuario, tabla, privilegio;

-- 4. UPDATE por columna que debe existir sin UPDATE global de tabla.
WITH esperados(usuario, tabla, columna) AS (
    VALUES
    ('usr_encargado_sucursal_01'::name,'repartidor'::name,'activo'::name),
    ('usr_repartidor_01','asignacion_ruta','fecha_llegada'),
    ('usr_repartidor_01','asignacion_ruta','observaciones')
)
SELECT usuario, tabla, columna,
       has_column_privilege(usuario, format('%I.%I','public',tabla), columna, 'UPDATE')
           AS tiene_update_columna,
       has_table_privilege(usuario, format('%I.%I','public',tabla), 'UPDATE')
           AS tiene_update_tabla,
       CASE WHEN has_column_privilege(usuario, format('%I.%I','public',tabla), columna, 'UPDATE')
                  AND NOT has_table_privilege(usuario, format('%I.%I','public',tabla), 'UPDATE')
            THEN 'OK' ELSE 'REVISAR' END AS resultado
FROM esperados
ORDER BY usuario, tabla, columna;

-- 5. Privilegios administrativos que no deben tener las cuentas funcionales.
SELECT rolname AS usuario, rolsuper, rolcreatedb, rolcreaterole,
       rolreplication, rolbypassrls,
       CASE WHEN rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls
            THEN 'REVISAR' ELSE 'OK' END AS resultado
FROM pg_roles
WHERE rolname IN ('usr_gerencia_01','usr_encargado_sucursal_01',
 'usr_recepcionista_01','usr_repartidor_01','usr_contabilidad_01',
 'usr_auditor_01','usr_backup_01','usr_dba_01')
ORDER BY rolname;

-- 6. Secuencias: inventario, identity y privilegios efectivos.
SELECT n.nspname AS esquema, s.relname AS secuencia,
       pg_get_userbyid(s.relowner) AS propietario
FROM pg_class s JOIN pg_namespace n ON n.oid=s.relnamespace
WHERE s.relkind='S' AND n.nspname='public'
ORDER BY s.relname;

WITH usuarios(usuario) AS (
 VALUES ('usr_gerencia_01'::name),('usr_encargado_sucursal_01'),
 ('usr_recepcionista_01'),('usr_repartidor_01'),('usr_contabilidad_01'),
 ('usr_auditor_01'),('usr_backup_01'),('usr_dba_01')
)
SELECT u.usuario, n.nspname AS esquema, s.relname AS secuencia,
       has_sequence_privilege(u.usuario, s.oid, 'USAGE') AS usage,
       has_sequence_privilege(u.usuario, s.oid, 'SELECT') AS select,
       has_sequence_privilege(u.usuario, s.oid, 'UPDATE') AS update
FROM usuarios u CROSS JOIN pg_class s
JOIN pg_namespace n ON n.oid=s.relnamespace
WHERE s.relkind='S' AND n.nspname='public'
  AND EXISTS (SELECT 1 FROM pg_roles r WHERE r.rolname=u.usuario)
ORDER BY u.usuario, s.relname;

-- 7. Funciones auxiliares y permisos EXECUTE.
WITH f(nombre, firma, rol_esperado) AS (
 VALUES
 ('usuario_tiene_sucursal','seguridad.usuario_tiene_sucursal(integer)','rol_encargado_sucursal'),
 ('usuario_tiene_sucursal','seguridad.usuario_tiene_sucursal(integer)','rol_recepcionista'),
 ('usuario_tiene_sucursal','seguridad.usuario_tiene_sucursal(integer)','rol_repartidor'),
 ('usuario_es_repartidor','seguridad.usuario_es_repartidor(integer)','rol_repartidor'),
 ('usuario_puede_ver_encomienda','seguridad.usuario_puede_ver_encomienda(integer)','rol_encargado_sucursal'),
 ('usuario_puede_ver_encomienda','seguridad.usuario_puede_ver_encomienda(integer)','rol_recepcionista'),
 ('usuario_puede_ver_encomienda','seguridad.usuario_puede_ver_encomienda(integer)','rol_repartidor')
)
SELECT f.nombre, f.rol_esperado,
       to_regprocedure(f.firma) IS NOT NULL AS existe,
       CASE WHEN to_regprocedure(f.firma) IS NULL THEN FALSE
            ELSE has_function_privilege(f.rol_esperado, to_regprocedure(f.firma), 'EXECUTE')
       END AS execute_concedido,
       CASE WHEN to_regprocedure(f.firma) IS NOT NULL
                  AND has_function_privilege(f.rol_esperado, to_regprocedure(f.firma), 'EXECUTE')
            THEN 'OK' ELSE 'REVISAR' END AS resultado
FROM f ORDER BY f.nombre, f.rol_esperado;

-- 8. Tablas auxiliares: el acceso directo no debe estar abierto a PUBLIC.
SELECT c.relname AS tabla,
       has_table_privilege('PUBLIC', format('%I.%I','seguridad',c.relname), 'SELECT') AS public_select,
       has_table_privilege('PUBLIC', format('%I.%I','seguridad',c.relname), 'INSERT') AS public_insert
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='seguridad' AND c.relkind IN ('r','p')
ORDER BY c.relname;

-- 9. Estado de RLS: esta consulta informa; no presupone que este activado.
SELECT n.nspname AS esquema, c.relname AS tabla,
       c.relrowsecurity AS rls_habilitado,
       c.relforcerowsecurity AS rls_forzado,
       COUNT(p.policyname) AS cantidad_politicas,
       CASE WHEN c.relrowsecurity THEN 'HABILITADO'
            ELSE 'NO IMPLEMENTADO' END AS estado
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
LEFT JOIN pg_policies p ON p.schemaname=n.nspname AND p.tablename=c.relname
WHERE n.nspname='public' AND c.relkind IN ('r','p')
GROUP BY n.nspname,c.relname,c.relrowsecurity,c.relforcerowsecurity
ORDER BY c.relname;

\echo 'Fin de 07. Las diferencias mostradas requieren revision; no se modifico nada.'
