\set ON_ERROR_STOP on

/*
===============================================================================
PROYECTO: ENVÍO SEGURO
ARCHIVO: 01_crear_roles.sql
PROPÓSITO:
    Crear los roles grupales (NOLOGIN) que representarán las funciones de
    negocio y seguridad de la empresa. Los usuarios individuales se crearán
    en un archivo posterior y heredarán permisos mediante membresí­a.

MOTOR / ENTORNO:
    PostgreSQL 17 | Windows | psql | puerto 5437 | base envio_seguro

PRERREQUISITOS:
    - Ejecutar conectado a la base envio_seguro.
    - La cuenta ejecutora debe tener CREATEROLE y los privilegios necesarios
      para modificar ACL de la base y del esquema public.
    - Ejecutar primero 00_verificar_entorno.sql.

EFECTOS:
    - Crea ocho roles grupales si todaví­a no existen.
    - Ninguno puede iniciar sesión ni es superusuario.
    - Ninguno puede crear bases de datos, roles ni replicar.
    - Revoca CREATE en public a PUBLIC.
    - Concede CONNECT a los roles funcionales.
    - No concede todavÃ­a permisos sobre tablas ni secuencias.
    - No concede privilegios de superusuario al rol_dba.
    - No configura todavÃ­a la cuenta técnica ni los privilegios de backup.

RE-EJECUCIÓN:
    El bloque de creación comprueba la existencia de cada rol. Los GRANT y
    REVOKE pueden repetirse sin duplicar privilegios.

SEGURIDAD:
    No incluir contraseñas en este archivo ni en Git.
===============================================================================
*/

\echo 'Iniciando creación de roles grupales...'

BEGIN;

DO $crear_roles$
DECLARE
    nombre_rol text;
    roles text[] := ARRAY[
        'rol_dba',
        'rol_gerencia',
        'rol_encargado_sucursal',
        'rol_recepcionista',
        'rol_repartidor',
        'rol_contabilidad',
        'rol_auditor',
        'rol_backup'
    ];
BEGIN
    FOREACH nombre_rol IN ARRAY roles
    LOOP
        IF NOT EXISTS (
            SELECT 1
            FROM pg_catalog.pg_roles
            WHERE rolname = nombre_rol
        ) THEN
            EXECUTE format('CREATE ROLE %I', nombre_rol);
            RAISE NOTICE 'Rol creado: %', nombre_rol;
        ELSE
            RAISE NOTICE 'El rol ya existe: %', nombre_rol;
        END IF;
    END LOOP;
END
$crear_roles$;

-- ---------------------------------------------------------------------------
-- Atributos comunes: roles de grupo, no cuentas de inicio de sesión.
-- ---------------------------------------------------------------------------
ALTER ROLE rol_dba                  NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
ALTER ROLE rol_gerencia             NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
ALTER ROLE rol_encargado_sucursal   NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
ALTER ROLE rol_recepcionista        NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
ALTER ROLE rol_repartidor           NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
ALTER ROLE rol_contabilidad         NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
ALTER ROLE rol_auditor              NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
ALTER ROLE rol_backup               NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;

-- ---------------------------------------------------------------------------
-- Base de datos: el permiso CONNECT se concede expresamente a los roles.
-- Se evita revocar CONNECT de PUBLIC en esta primera etapa para no bloquear
-- accidentalmente cuentas existentes ajenas al proyecto. Se revisará como
-- decisión de endurecimiento cuando está inventariado el acceso actual.
-- ---------------------------------------------------------------------------
GRANT CONNECT ON DATABASE envio_seguro TO
    rol_dba,
    rol_gerencia,
    rol_encargado_sucursal,
    rol_recepcionista,
    rol_repartidor,
    rol_contabilidad,
    rol_auditor,
    rol_backup;

-- ---------------------------------------------------------------------------
-- Esquema public:
-- USAGE permite resolver objetos; CREATE no se concede a los roles funcionales.
-- ---------------------------------------------------------------------------
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

GRANT USAGE ON SCHEMA public TO
    rol_dba,
    rol_gerencia,
    rol_encargado_sucursal,
    rol_recepcionista,
    rol_repartidor,
    rol_contabilidad,
    rol_auditor,
    rol_backup;

COMMIT;

\echo 'Roles creados/configurados. Verificando atributos...'

SELECT
    rolname AS nombre_rol,
    rolcanlogin AS permite_login,
    rolsuper AS superusuario,
    rolcreatedb AS puede_crear_bases,
    rolcreaterole AS puede_crear_roles,
    rolreplication AS puede_replicar,
    rolbypassrls AS omite_rls
FROM pg_catalog.pg_roles
WHERE rolname IN (
    'rol_dba',
    'rol_gerencia',
    'rol_encargado_sucursal',
    'rol_recepcionista',
    'rol_repartidor',
    'rol_contabilidad',
    'rol_auditor',
    'rol_backup'
)
ORDER BY rolname;

\echo 'Fin de 01_crear_roles.sql'
