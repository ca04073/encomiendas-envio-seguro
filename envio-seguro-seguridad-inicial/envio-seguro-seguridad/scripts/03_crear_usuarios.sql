/*
===============================================================================
PROYECTO: ENVÍO-SEGURO
ARCHIVO: 03_crear_usuarios.sql
PROPÓSITO:
    Crear cuentas individuales LOGIN y asignarlas a los roles funcionales
    definidos en 01_crear_roles.sql.

REQUISITOS:
    - PostgreSQL 17.
    - Ejecutar conectado a envio_seguro.
    - Ejecutar con una cuenta autorizada para CREATEROLE.
    - Haber ejecutado 01_crear_roles.sql y 02_configurar_permisos.sql.

SEGURIDAD:
    - Este archivo NO establece contraseñas.
    - No guardar contraseñas en Git ni en scripts SQL.
    - Después de crear las cuentas, establecer cada contraseña con \password
      desde psql.
    - Los nombres incluidos son identificadores de ejemplo. Reemplazarlos
      por los identificadores institucionales antes de ejecutar.
    - Asignar rol_dba únicamente a personal autorizado para esa función.

COMPORTAMIENTO:
    - Crea las cuentas que no existan.
    - Si una cuenta ya existe, normaliza sus atributos LOGIN y de seguridad.
    - Concede la membresía funcional indicada.
    - No elimina cuentas ni revoca otras membresías existentes.
===============================================================================
*/

\set ON_ERROR_STOP on
\encoding UTF8

-- Validar base de datos y versión del servidor.
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
-- 1. Definir las cuentas que se crearán
-- ---------------------------------------------------------------------------
-- Agregar una fila por cada empleado. Cambiar los nombres de ejemplo antes
-- de ejecutar el script en un entorno real.

DROP TABLE IF EXISTS pg_temp.usuarios_a_crear;

CREATE TEMP TABLE usuarios_a_crear (
    nombre_login  name PRIMARY KEY,
    rol_funcional name NOT NULL
) ON COMMIT PRESERVE ROWS;

INSERT INTO usuarios_a_crear (nombre_login, rol_funcional) VALUES
    ('usr_gerencia_01',             'rol_gerencia'),
    ('usr_encargado_sucursal_01',   'rol_encargado_sucursal'),
    ('usr_recepcionista_01',        'rol_recepcionista'),
    ('usr_repartidor_01',           'rol_repartidor'),
    ('usr_contabilidad_01',         'rol_contabilidad'),
    ('usr_auditor_01',              'rol_auditor'),
    ('usr_backup_01',               'rol_backup'),
    ('usr_dba_01',                  'rol_dba');

-- ---------------------------------------------------------------------------
-- 2. Verificar que los roles funcionales existan
-- ---------------------------------------------------------------------------

DO $$
DECLARE
    v_rol name;
BEGIN
    FOR v_rol IN
        SELECT DISTINCT rol_funcional
        FROM usuarios_a_crear
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM pg_roles WHERE rolname = v_rol
        ) THEN
            RAISE EXCEPTION
                'El rol funcional "%" no existe. Ejecute 01_crear_roles.sql.',
                v_rol;
        END IF;
    END LOOP;
END
$$;

-- ---------------------------------------------------------------------------
-- 3. Crear/normalizar cuentas y conceder membresías
-- ---------------------------------------------------------------------------

DO $$
DECLARE
    v_usuario record;
BEGIN
    FOR v_usuario IN
        SELECT nombre_login, rol_funcional
        FROM usuarios_a_crear
        ORDER BY nombre_login
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM pg_roles WHERE rolname = v_usuario.nombre_login
        ) THEN
            EXECUTE format(
                'CREATE ROLE %I LOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS',
                v_usuario.nombre_login
            );
            RAISE NOTICE 'Cuenta creada: %', v_usuario.nombre_login;
        ELSE
            -- No cambia la contraseña ni elimina otras membresías.
            EXECUTE format(
                'ALTER ROLE %I LOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS',
                v_usuario.nombre_login
            );
            RAISE NOTICE 'Cuenta existente revisada: %', v_usuario.nombre_login;
        END IF;

        EXECUTE format(
            'GRANT %I TO %I',
            v_usuario.rol_funcional,
            v_usuario.nombre_login
        );

        RAISE NOTICE 'Asignado % a %',
            v_usuario.rol_funcional,
            v_usuario.nombre_login;
    END LOOP;
END
$$;

-- ---------------------------------------------------------------------------
-- 4. Reporte de verificación
-- ---------------------------------------------------------------------------

SELECT
    u.nombre_login AS usuario,
    u.rol_funcional AS rol_asignado,
    r.rolcanlogin AS puede_iniciar_sesion,
    r.rolsuper AS superusuario,
    r.rolcreatedb AS puede_crear_bases,
    r.rolcreaterole AS puede_crear_roles,
    r.rolreplication AS replicacion,
    r.rolbypassrls AS omite_rls
FROM usuarios_a_crear AS u
JOIN pg_roles AS r
  ON r.rolname = u.nombre_login
ORDER BY u.nombre_login;

-- ---------------------------------------------------------------------------
-- 5. Establecer contraseñas manualmente desde psql
-- ---------------------------------------------------------------------------
-- Ejecutar una vez por cuenta, usando los nombres definitivos:
--
\password usr_gerencia_01
\password usr_encargado_sucursal_01
\password usr_recepcionista_01
\password usr_repartidor_01
\password usr_contabilidad_01
\password usr_auditor_01
\password usr_backup_01
\password usr_dba_01
--
-- \password solicita la contraseña interactivamente. No escribirla en este
-- archivo, en el historial SQL ni en el repositorio.
--
-- Revisar también pg_hba.conf para confirmar que el método de autenticación
-- corresponde a la política de seguridad del proyecto.
--
-- FIN DEL SCRIPT
