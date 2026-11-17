\set ON_ERROR_STOP on
/*
===============================================================================
PROYECTO: ENVÍO SEGURO
ARCHIVO: 02_configurar_permisos.sql
VERSIÓN: 1.0
ENTORNO: PostgreSQL 17 | Windows | psql | localhost:5437
BASE: envio_seguro

PROPÓSITO:
    Asignar privilegios diferenciados sobre las tablas existentes de public
    según la responsabilidad de cada rol. Aplica el principio de mínimo
    privilegio.

PRERREQUISITOS:
    - Conectarse a envio_seguro.
    - Ejecutar 00_verificar_entorno.sql y 01_crear_roles.sql.
    - La cuenta ejecutora debe ser propietaria de las tablas o estar autorizada
      para conceder/revocar sus privilegios.

ALCANCE:
    - Configura privilegios sobre tablas existentes.
    - No crea usuarios ni configura secuencias, RLS o respaldos físicos.
    - rol_dba no es SUPERUSER ni recibe propiedad automática de objetos.

RE-EJECUCIÓN:
    Revoca primero los privilegios de tabla concedidos directamente a los
    ocho roles del proyecto y luego aplica esta matriz. No modifica permisos
    recibidos por membresía desde otros roles ni ACL de usuarios individuales.

NOTAS:
    - Los privilegios se acumulan entre todos los roles de los que un usuario
      sea miembro. REVOKE de un rol no neutraliza permisos recibidos por otro.
    - GRANT sobre una tabla no limita filas; el aislamiento por sucursal exige
      RLS y una identidad de sucursal validada.
    - No se concede DELETE a roles operativos ordinarios.
    - No se concede TRUNCATE, TRIGGER ni REFERENCES.
    - rol_backup recibe SELECT para respaldos lógicos; pg_basebackup/WAL se
      configuran por separado.
===============================================================================
*/

-- Validación defensiva del destino y versión.
DO $validar$
BEGIN
    IF current_database() <> 'envio_seguro' THEN
        RAISE EXCEPTION 'Base incorrecta: se esperaba envio_seguro; actual: %',
            current_database();
    END IF;

    IF current_setting('server_version_num')::integer / 10000 <> 17 THEN
        RAISE EXCEPTION 'Se requiere PostgreSQL 17; versión detectada: %',
            current_setting('server_version');
    END IF;
END
$validar$;

BEGIN;

-- Limpiar privilegios previos de tabla asignados directamente a estos roles.
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM
    rol_dba, rol_gerencia, rol_encargado_sucursal, rol_recepcionista,
    rol_repartidor, rol_contabilidad, rol_auditor, rol_backup;

-- 1. DBA delegado: DML sobre tablas existentes; no implica SUPERUSER ni DDL.
GRANT SELECT, INSERT, UPDATE, DELETE
ON ALL TABLES IN SCHEMA public TO rol_dba;

-- 2. Gerencia: lectura de información empresarial, logística y financiera.
GRANT SELECT ON TABLE
    agencia, sucursal, encomienda, estado_encomienda, guia_envio,
    ruta, asignacion_ruta, evento_rastreo, pago, metodo_pago,
    documento_dte, tipo_dte, estado_dte, servicio_tarifa, detalle_dte,
    incidencia, tipo_incidencia
TO rol_gerencia;

-- 3. Encargado de sucursal: consulta y gestión operativa/logística.
-- El filtrado efectivo por sucursal se implementará mediante RLS.
GRANT SELECT ON TABLE
    sucursal, empleado, repartidor, cliente, estado_encomienda, encomienda,
    guia_envio, ruta, asignacion_ruta, evento_rastreo,
    tipo_incidencia, incidencia
TO rol_encargado_sucursal;

GRANT INSERT, UPDATE ON TABLE
    ruta, asignacion_ruta, incidencia
TO rol_encargado_sucursal;

GRANT INSERT ON TABLE evento_rastreo TO rol_encargado_sucursal;
GRANT UPDATE (activo) ON TABLE repartidor TO rol_encargado_sucursal;

-- 4. Recepción: registra clientes, envíos, guías y pagos recibidos.
GRANT SELECT ON TABLE
    sucursal, cliente, estado_encomienda, encomienda, guia_envio,
    empleado, metodo_pago
TO rol_recepcionista;

GRANT INSERT, UPDATE ON TABLE cliente TO rol_recepcionista;
GRANT INSERT ON TABLE
    encomienda, guia_envio, evento_rastreo, pago
TO rol_recepcionista;

-- 5. Repartidor: lectura logística, eventos e incidencias.
-- Solo puede actualizar las columnas de cierre de una asignación.
GRANT SELECT ON TABLE
    sucursal, estado_encomienda, encomienda, ruta,
    asignacion_ruta, evento_rastreo, tipo_incidencia
TO rol_repartidor;

GRANT UPDATE (fecha_llegada, observaciones)
ON TABLE asignacion_ruta TO rol_repartidor;

GRANT INSERT ON TABLE evento_rastreo, incidencia TO rol_repartidor;

-- 6. Contabilidad: consulta y gestión de pagos y documentos fiscales.
GRANT SELECT ON TABLE
    cliente, encomienda, guia_envio, pago, metodo_pago,
    documento_dte, detalle_dte, tipo_dte, estado_dte, servicio_tarifa
TO rol_contabilidad;

GRANT INSERT, UPDATE ON TABLE
    pago, documento_dte, detalle_dte
TO rol_contabilidad;

-- 7. Auditoría: lectura de todas las tablas existentes.
GRANT SELECT ON ALL TABLES IN SCHEMA public TO rol_auditor;

-- 8. Backup lógico: lectura de todas las tablas existentes.
-- Los permisos de secuencias se revisarán por separado.
GRANT SELECT ON ALL TABLES IN SCHEMA public TO rol_backup;

COMMIT;

-- Informe de privilegios concedidos directamente a los roles del proyecto.
\echo '--- Privilegios de tabla por rol ---'
SELECT
    grantee AS rol,
    table_name AS tabla,
    string_agg(privilege_type, ', ' ORDER BY privilege_type) AS privilegios
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND grantee IN (
      'rol_dba', 'rol_gerencia', 'rol_encargado_sucursal',
      'rol_recepcionista', 'rol_repartidor', 'rol_contabilidad',
      'rol_auditor', 'rol_backup'
  )
GROUP BY grantee, table_name
ORDER BY grantee, table_name;

\echo '--- Fin de 02_configurar_permisos.sql ---'
