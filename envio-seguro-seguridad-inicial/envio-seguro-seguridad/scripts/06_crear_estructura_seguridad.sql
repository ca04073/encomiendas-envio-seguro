-- =====================================================================
-- Proyecto: ENVIO-SEGURO
-- Fase 06: Estructura base para seguridad por filas (RLS)
-- PostgreSQL 17
--
-- Ejecutar conectado a envio_seguro. Nótese: las funciones serán propiedad del usuario 
--que ejecute el script (probablemente postgres).
-- Este script NO activa RLS ni concede permisos sobre tablas de negocio.
-- Las tablas de asignacion quedan vacias hasta registrar datos reales.
-- =====================================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS seguridad AUTHORIZATION CURRENT_USER;
REVOKE ALL ON SCHEMA seguridad FROM PUBLIC;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- Una cuenta puede tener acceso a varias sucursales.
CREATE TABLE IF NOT EXISTS seguridad.usuario_sucursal (
    usuario NAME NOT NULL,
    id_sucursal INTEGER NOT NULL,
    fecha_alta TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_usuario_sucursal PRIMARY KEY (usuario, id_sucursal),
    CONSTRAINT fk_usuario_sucursal_sucursal
        FOREIGN KEY (id_sucursal)
        REFERENCES public.sucursal (id_sucursal)
        ON UPDATE RESTRICT ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_usuario_sucursal_id_sucursal
    ON seguridad.usuario_sucursal (id_sucursal);

-- Una cuenta corresponde a un repartidor.
CREATE TABLE IF NOT EXISTS seguridad.usuario_repartidor (
    usuario NAME NOT NULL,
    id_repartidor INTEGER NOT NULL,
    fecha_alta TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_usuario_repartidor PRIMARY KEY (usuario),
    CONSTRAINT uq_usuario_repartidor_id UNIQUE (id_repartidor),
    CONSTRAINT fk_usuario_repartidor_repartidor
        FOREIGN KEY (id_repartidor)
        REFERENCES public.repartidor (id_repartidor)
        ON UPDATE RESTRICT ON DELETE RESTRICT
);

-- SESSION_USER identifica el login original aunque se use SET ROLE.
-- SECURITY DEFINER permite consultar las tablas privadas de asignacion.
-- El search_path esta fijado y los objetos se califican con su esquema.

CREATE OR REPLACE FUNCTION seguridad.usuario_tiene_sucursal(
    p_id_sucursal INTEGER
)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, seguridad
AS $function$
    SELECT EXISTS (
        SELECT 1
        FROM seguridad.usuario_sucursal AS us
        WHERE us.usuario = SESSION_USER::NAME
          AND us.id_sucursal = p_id_sucursal
    );
$function$;

CREATE OR REPLACE FUNCTION seguridad.usuario_es_repartidor(
    p_id_repartidor INTEGER
)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, seguridad
AS $function$
    SELECT EXISTS (
        SELECT 1
        FROM seguridad.usuario_repartidor AS ur
        WHERE ur.usuario = SESSION_USER::NAME
          AND ur.id_repartidor = p_id_repartidor
    );
$function$;

-- Acceso a encomienda por sucursal origen/destino o asignacion personal.
CREATE OR REPLACE FUNCTION seguridad.usuario_puede_ver_encomienda(
    p_id_encomienda INTEGER
)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, seguridad
AS $function$
    SELECT EXISTS (
        SELECT 1
        FROM public.encomienda AS e
        WHERE e.id_encomienda = p_id_encomienda
          AND (
              EXISTS (
                  SELECT 1
                  FROM seguridad.usuario_sucursal AS us
                  WHERE us.usuario = SESSION_USER::NAME
                    AND us.id_sucursal IN (
                        e.id_sucursal_origen,
                        e.id_sucursal_destino
                    )
              )
              OR EXISTS (
                  SELECT 1
                  FROM public.asignacion_ruta AS ar
                  JOIN seguridad.usuario_repartidor AS ur
                    ON ur.id_repartidor = ar.id_repartidor
                  WHERE ar.id_encomienda = e.id_encomienda
                    AND ur.usuario = SESSION_USER::NAME
              )
          )
    );
$function$;

-- Sin acceso directo a las tablas auxiliares.
REVOKE ALL ON ALL TABLES IN SCHEMA seguridad FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA seguridad FROM PUBLIC;

REVOKE ALL ON FUNCTION seguridad.usuario_tiene_sucursal(INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION seguridad.usuario_es_repartidor(INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION seguridad.usuario_puede_ver_encomienda(INTEGER) FROM PUBLIC;

-- Las politicas RLS futuras llamaran estos helpers.
GRANT USAGE ON SCHEMA seguridad TO
    rol_encargado_sucursal, rol_recepcionista, rol_repartidor;

GRANT EXECUTE ON FUNCTION seguridad.usuario_tiene_sucursal(INTEGER) TO
    rol_encargado_sucursal, rol_recepcionista, rol_repartidor;

GRANT EXECUTE ON FUNCTION seguridad.usuario_es_repartidor(INTEGER) TO
    rol_repartidor;

GRANT EXECUTE ON FUNCTION seguridad.usuario_puede_ver_encomienda(INTEGER) TO
    rol_encargado_sucursal, rol_recepcionista, rol_repartidor;

COMMENT ON SCHEMA seguridad IS
    'Private schema for identity mappings and RLS helper functions.';
COMMENT ON TABLE seguridad.usuario_sucursal IS
    'Maps PostgreSQL login roles to the branches they may operate.';
COMMENT ON TABLE seguridad.usuario_repartidor IS
    'Maps a PostgreSQL login role to its delivery worker record.';

COMMIT;

-- Verificacion: deben existir dos tablas y tres funciones.
SELECT n.nspname AS esquema, c.relname AS objeto,
       CASE c.relkind WHEN 'r' THEN 'tabla' WHEN 'i' THEN 'indice'
            ELSE c.relkind::TEXT END AS tipo
FROM pg_catalog.pg_class AS c
JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
WHERE n.nspname = 'seguridad'
ORDER BY tipo, objeto;

SELECT routine_schema, routine_name, security_type, routine_type
FROM information_schema.routines
WHERE routine_schema = 'seguridad'
ORDER BY routine_name;

-- Ambas tablas deben estar vacias inicialmente.
SELECT * FROM seguridad.usuario_sucursal ORDER BY usuario, id_sucursal;
SELECT * FROM seguridad.usuario_repartidor ORDER BY usuario;
