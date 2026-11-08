\set ON_ERROR_STOP on
\encoding UTF8

/*
===============================================================================
PROYECTO: ENVIO-SEGURO
ARCHIVO: 08_auditoria_final_seguridad.sql
MOTOR: PostgreSQL 17 | psql
PROPOSITO:
    Informe de auditoria de roles, usuarios, membresias, ACL, secuencias,
    esquema seguridad, funciones SECURITY DEFINER y politicas RLS.
SEGURIDAD:
    Solo lectura. No ejecuta GRANT, REVOKE, DDL ni DML.
    La auditoria debe ejecutarse con una cuenta capaz de consultar catalogos.
LIMITES:
    No demuestra el comportamiento de una sesion autenticada ni sustituye
    pruebas funcionales de RLS con usuarios reales.
===============================================================================
*/

\echo '============================================================'
\echo '08 - AUDITORIA FINAL DE SEGURIDAD'
\echo '============================================================'

DO $validar$
BEGIN
 IF current_database() <> 'envio_seguro' THEN
   RAISE EXCEPTION 'Base incorrecta: se esperaba envio_seguro.';
 END IF;
 IF current_setting('server_version_num')::integer / 10000 <> 17 THEN
   RAISE EXCEPTION 'Se requiere PostgreSQL 17.';
 END IF;
END
$validar$;

-- 1. Roles grupales y atributos.
SELECT rolname, rolcanlogin, rolsuper, rolcreatedb, rolcreaterole,
       rolreplication, rolbypassrls, rolconnlimit
FROM pg_roles
WHERE rolname IN ('rol_dba','rol_gerencia','rol_encargado_sucursal',
 'rol_recepcionista','rol_repartidor','rol_contabilidad','rol_auditor','rol_backup')
ORDER BY rolname;

-- 2. Cuentas LOGIN y atributos.
SELECT rolname, rolcanlogin, rolsuper, rolcreatedb, rolcreaterole,
       rolreplication, rolbypassrls, rolvaliduntil
FROM pg_roles
WHERE rolname IN ('usr_gerencia_01','usr_encargado_sucursal_01',
 'usr_recepcionista_01','usr_repartidor_01','usr_contabilidad_01',
 'usr_auditor_01','usr_backup_01','usr_dba_01')
ORDER BY rolname;

-- 3. Membresias: incluye opciones disponibles en PostgreSQL 17.
SELECT member.rolname AS miembro, granted.rolname AS rol_concedido,
       am.admin_option, am.inherit_option, am.set_option,
       grantor.rolname AS concedido_por
FROM pg_auth_members am
JOIN pg_roles granted ON granted.oid=am.roleid
JOIN pg_roles member ON member.oid=am.member
JOIN pg_roles grantor ON grantor.oid=am.grantor
WHERE member.rolname IN ('usr_gerencia_01','usr_encargado_sucursal_01',
 'usr_recepcionista_01','usr_repartidor_01','usr_contabilidad_01',
 'usr_auditor_01','usr_backup_01','usr_dba_01')
   OR granted.rolname LIKE 'rol\_%' ESCAPE '\'
ORDER BY miembro, rol_concedido;

-- 4. Privilegios efectivos de tabla para las cuentas.
WITH usuarios(usuario) AS (
 VALUES ('usr_gerencia_01'::name),('usr_encargado_sucursal_01'),
 ('usr_recepcionista_01'),('usr_repartidor_01'),('usr_contabilidad_01'),
 ('usr_auditor_01'),('usr_backup_01'),('usr_dba_01')
)
SELECT u.usuario, n.nspname AS esquema, c.relname AS tabla,
       has_table_privilege(u.usuario,c.oid,'SELECT') AS puede_select,
       has_table_privilege(u.usuario,c.oid,'INSERT') AS puede_insert,
       has_table_privilege(u.usuario,c.oid,'UPDATE') AS puede_update,
       has_table_privilege(u.usuario,c.oid,'DELETE') AS puede_delete,
       has_table_privilege(u.usuario,c.oid,'TRUNCATE') AS puede_truncate
FROM usuarios u CROSS JOIN pg_class c
JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relkind IN ('r','p')
  AND EXISTS (SELECT 1 FROM pg_roles r WHERE r.rolname=u.usuario)
ORDER BY u.usuario,c.relname;

-- 5. Privilegios de columnas (muestra ACL explicitas).
SELECT grantee, table_name, column_name, privilege_type, is_grantable
FROM information_schema.column_privileges
WHERE table_schema='public'
  AND grantee IN ('rol_dba','rol_gerencia','rol_encargado_sucursal',
   'rol_recepcionista','rol_repartidor','rol_contabilidad','rol_auditor',
   'rol_backup','usr_gerencia_01','usr_encargado_sucursal_01',
   'usr_recepcionista_01','usr_repartidor_01','usr_contabilidad_01',
   'usr_auditor_01','usr_backup_01','usr_dba_01')
ORDER BY grantee,table_name,column_name,privilege_type;

-- 6. Privilegios de esquema.
SELECT r.rolname AS rol,
       has_schema_privilege(r.rolname,'public','USAGE') AS public_usage,
       has_schema_privilege(r.rolname,'public','CREATE') AS public_create,
       CASE WHEN to_regnamespace('seguridad') IS NULL THEN NULL
            ELSE has_schema_privilege(r.rolname,'seguridad','USAGE') END AS seguridad_usage,
       CASE WHEN to_regnamespace('seguridad') IS NULL THEN NULL
            ELSE has_schema_privilege(r.rolname,'seguridad','CREATE') END AS seguridad_create
FROM pg_roles r
WHERE r.rolname IN ('rol_dba','rol_gerencia','rol_encargado_sucursal',
 'rol_recepcionista','rol_repartidor','rol_contabilidad','rol_auditor',
 'rol_backup','usr_gerencia_01','usr_encargado_sucursal_01',
 'usr_recepcionista_01','usr_repartidor_01','usr_contabilidad_01',
 'usr_auditor_01','usr_backup_01','usr_dba_01')
ORDER BY r.rolname;

-- 7. Inventario de secuencias y ACL.
SELECT n.nspname AS esquema, c.relname AS secuencia,
       pg_get_userbyid(c.relowner) AS propietario,
       c.relacl AS acl
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE c.relkind='S' AND n.nspname='public'
ORDER BY c.relname;

-- 8. Columnas identity/serial y secuencia asociada.
SELECT table_schema, table_name, column_name, is_identity,
       identity_generation, column_default,
       pg_get_serial_sequence(format('%I.%I',table_schema,table_name),column_name)
           AS secuencia_asociada
FROM information_schema.columns
WHERE table_schema='public'
  AND (is_identity='YES' OR column_default LIKE 'nextval(%')
ORDER BY table_name,ordinal_position;

-- 9. Esquema seguridad, tablas y propietarios.
SELECT n.nspname AS esquema, pg_get_userbyid(n.nspowner) AS propietario,
       n.nspacl AS acl
FROM pg_namespace n WHERE n.nspname='seguridad';

SELECT n.nspname AS esquema, c.relname AS objeto,
       CASE c.relkind WHEN 'r' THEN 'tabla' WHEN 'p' THEN 'tabla particionada'
                      WHEN 'i' THEN 'indice' ELSE c.relkind::text END AS tipo,
       pg_get_userbyid(c.relowner) AS propietario, c.relacl AS acl
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='seguridad'
ORDER BY c.relkind,c.relname;

-- 10. Funciones: propietario, SECURITY DEFINER, search_path y definicion.
SELECT n.nspname AS esquema, p.proname AS funcion,
       pg_get_function_identity_arguments(p.oid) AS argumentos,
       pg_get_userbyid(p.proowner) AS propietario,
       p.prosecdef AS security_definer,
       p.provolatile AS volatilidad,
       p.proconfig AS configuracion,
       pg_get_function_result(p.oid) AS retorno,
       p.proacl AS acl,
       pg_get_functiondef(p.oid) AS definicion
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='seguridad'
ORDER BY p.proname;

-- 11. Privilegios EXECUTE efectivos para las funciones auxiliares.
WITH funciones AS (
 SELECT p.oid, p.proname,
        p.oid::regprocedure::text AS firma
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='seguridad'
   AND p.proname IN ('usuario_tiene_sucursal','usuario_es_repartidor',
                     'usuario_puede_ver_encomienda')
),
roles(rol) AS (
 VALUES ('rol_encargado_sucursal'::name),('rol_recepcionista'),
        ('rol_repartidor'),('rol_gerencia'),('rol_auditor')
)
SELECT f.firma, r.rol,
       has_function_privilege(r.rol,f.oid,'EXECUTE') AS puede_ejecutar
FROM funciones f CROSS JOIN roles r
ORDER BY f.firma,r.rol;

-- 12. RLS: estado por tabla y politicas configuradas.
SELECT n.nspname AS esquema, c.relname AS tabla,
       c.relrowsecurity AS rls_habilitado,
       c.relforcerowsecurity AS rls_forzado,
       COUNT(p.policyname) AS cantidad_politicas,
       CASE WHEN c.relrowsecurity THEN 'HABILITADO'
            ELSE 'NO IMPLEMENTADO' END AS diagnostico
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
LEFT JOIN pg_policies p ON p.schemaname=n.nspname AND p.tablename=c.relname
WHERE n.nspname='public' AND c.relkind IN ('r','p')
GROUP BY n.nspname,c.relname,c.relrowsecurity,c.relforcerowsecurity
ORDER BY c.relname;

SELECT schemaname, tablename, policyname, permissive,
       roles, cmd, qual, with_check
FROM pg_policies
WHERE schemaname IN ('public','seguridad')
ORDER BY schemaname,tablename,policyname;

-- 13. Resumen de alertas objetivas.
SELECT
 (SELECT COUNT(*) FROM pg_roles
  WHERE rolname IN ('rol_dba','rol_gerencia','rol_encargado_sucursal',
   'rol_recepcionista','rol_repartidor','rol_contabilidad','rol_auditor','rol_backup')
    AND (rolcanlogin OR rolsuper OR rolcreatedb OR rolcreaterole
         OR rolreplication OR rolbypassrls)) AS roles_grupales_con_atributos_inesperados,
 (SELECT COUNT(*) FROM pg_roles
  WHERE rolname IN ('usr_gerencia_01','usr_encargado_sucursal_01',
   'usr_recepcionista_01','usr_repartidor_01','usr_contabilidad_01',
   'usr_auditor_01','usr_backup_01','usr_dba_01')
    AND (rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls))
       AS usuarios_con_atributos_administrativos,
 (SELECT COUNT(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public' AND c.relkind IN ('r','p') AND c.relrowsecurity)
       AS tablas_public_con_rls,
 (SELECT COUNT(*) FROM pg_policies WHERE schemaname='public')
       AS politicas_rls_public;

\echo 'Fin de 08. Revisar especialmente funciones SECURITY DEFINER y RLS.'
\echo 'Este informe no modifica objetos, permisos ni datos.'
