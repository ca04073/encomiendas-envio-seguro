-- =====================================================================
-- 05_security_rls.sql: Seguridad Avanzada, RBAC, RLS y Cifrado pgcrypto
-- Proyecto: Sistema de Encomiendas "Envío Seguro" (ADB135)
-- =====================================================================

\echo '=== [05_security_rls] INICIANDO CONFIGURACIÓN DE SEGURIDAD ==='

-- ---------------------------------------------------------------------
-- 1. CREACIÓN DE ROLES GRUPALES (RBAC - NOLOGIN)
-- ---------------------------------------------------------------------
DO $crear_roles$
DECLARE
    r text;
    roles_list text[] := ARRAY[
        'rol_dba',
        'rol_gerencia',
        'rol_encargado_sucursal',
        'rol_recepcionista',
        'rol_repartidor',
        'rol_contabilidad',
        'rol_auditor'
    ];
BEGIN
    FOREACH r IN ARRAY roles_list
    LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
            EXECUTE format('CREATE ROLE %I WITH NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT;', r);
            RAISE NOTICE 'Rol creado: %', r;
        END IF;
    END LOOP;
END $crear_roles$;

-- Conceder conexión
GRANT CONNECT ON DATABASE envio_seguro TO 
    rol_dba, rol_gerencia, rol_encargado_sucursal, rol_recepcionista, 
    rol_repartidor, rol_contabilidad, rol_auditor;

GRANT USAGE ON SCHEMA public TO 
    rol_dba, rol_gerencia, rol_encargado_sucursal, rol_recepcionista, 
    rol_repartidor, rol_contabilidad, rol_auditor;

-- ---------------------------------------------------------------------
-- 2. MATRIZ DE PRIVILEGIOS MÍNIMOS (GRANT / REVOKE)
-- ---------------------------------------------------------------------

-- Limpiar permisos previos
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM 
    rol_dba, rol_gerencia, rol_encargado_sucursal, rol_recepcionista, 
    rol_repartidor, rol_contabilidad, rol_auditor;

-- 2.1. rol_dba: Operación total DML (sin superusuario)
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO rol_dba;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO rol_dba;

-- 2.2. rol_gerencia: Lectura total analítica y empresarial
GRANT SELECT ON ALL TABLES IN SCHEMA public TO rol_gerencia;

-- 2.3. rol_encargado_sucursal y rol_recepcionista: Operación de ventanilla
GRANT SELECT ON agencia, sucursal, empleado, estado_encomienda, tipo_incidencia, 
                servicio_tarifa, metodo_pago, tipo_dte, estado_dte TO rol_encargado_sucursal, rol_recepcionista;

GRANT SELECT, INSERT, UPDATE ON cliente, encomienda, guia_envio, evento_rastreo, 
                                pago, documento_dte, detalle_dte, incidencia TO rol_encargado_sucursal, rol_recepcionista;

GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO rol_encargado_sucursal, rol_recepcionista;

-- 2.4. rol_repartidor: Consulta de rutas y registro de entregas
GRANT SELECT ON sucursal, estado_encomienda, tipo_incidencia TO rol_repartidor;
GRANT SELECT ON encomienda, guia_envio, ruta, asignacion_ruta TO rol_repartidor;
GRANT INSERT ON evento_rastreo, incidencia TO rol_repartidor;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO rol_repartidor;

-- 2.5. rol_auditor: Solo lectura tributaria y contable
GRANT SELECT ON ALL TABLES IN SCHEMA public TO rol_auditor;

-- ---------------------------------------------------------------------
-- 3. ESQUEMA DE SEGURIDAD Y MAPEO DE IDENTIDADES
-- ---------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS seguridad;
REVOKE ALL ON SCHEMA seguridad FROM PUBLIC;

CREATE TABLE IF NOT EXISTS seguridad.usuario_sucursal (
    usuario NAME NOT NULL,
    id_sucursal INTEGER NOT NULL REFERENCES public.sucursal (id_sucursal),
    fecha_alta TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_usuario_sucursal PRIMARY KEY (usuario, id_sucursal)
);

CREATE TABLE IF NOT EXISTS seguridad.usuario_repartidor (
    usuario NAME NOT NULL PRIMARY KEY,
    id_repartidor INTEGER NOT NULL REFERENCES public.repartidor (id_repartidor),
    fecha_alta TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Funciones helper de verificación por rol
CREATE OR REPLACE FUNCTION seguridad.usuario_tiene_sucursal(p_id_sucursal INTEGER)
RETURNS BOOLEAN
LANGUAGE SQL STABLE
SET search_path = pg_catalog, seguridad
AS $$
    SELECT EXISTS (
        SELECT 1 FROM seguridad.usuario_sucursal us
        WHERE us.usuario = CURRENT_USER
          AND us.id_sucursal = p_id_sucursal
    );
$$;

CREATE OR REPLACE FUNCTION seguridad.usuario_es_repartidor(p_id_repartidor INTEGER)
RETURNS BOOLEAN
LANGUAGE SQL STABLE
SET search_path = pg_catalog, seguridad
AS $$
    SELECT EXISTS (
        SELECT 1 FROM seguridad.usuario_repartidor ur
        WHERE ur.usuario = CURRENT_USER
          AND ur.id_repartidor = p_id_repartidor
    );
$$;

GRANT USAGE ON SCHEMA seguridad TO 
    rol_dba, rol_gerencia, rol_encargado_sucursal, rol_recepcionista, rol_repartidor, rol_auditor;

GRANT SELECT ON seguridad.usuario_sucursal TO 
    rol_encargado_sucursal, rol_recepcionista, rol_repartidor, rol_dba;

GRANT SELECT ON seguridad.usuario_repartidor TO 
    rol_repartidor, rol_dba;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA seguridad TO 
    rol_dba, rol_gerencia, rol_encargado_sucursal, rol_recepcionista, rol_repartidor, rol_auditor;

-- ---------------------------------------------------------------------
-- 4. ROW-LEVEL SECURITY (RLS): AISLAMIENTO POR SUCURSAL
-- ---------------------------------------------------------------------
ALTER TABLE public.encomienda ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.evento_rastreo ENABLE ROW LEVEL SECURITY;

-- 4.1. Políticas para encomienda
DROP POLICY IF EXISTS pol_encomienda_admin_auditor ON public.encomienda;
CREATE POLICY pol_encomienda_admin_auditor ON public.encomienda
    FOR ALL
    TO rol_dba, rol_gerencia, rol_auditor, postgres
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS pol_encomienda_sucursal ON public.encomienda;
CREATE POLICY pol_encomienda_sucursal ON public.encomienda
    FOR ALL
    TO rol_encargado_sucursal, rol_recepcionista
    USING (
        seguridad.usuario_tiene_sucursal(id_sucursal_origen) OR 
        seguridad.usuario_tiene_sucursal(id_sucursal_destino)
    )
    WITH CHECK (
        seguridad.usuario_tiene_sucursal(id_sucursal_origen)
    );

DROP POLICY IF EXISTS pol_encomienda_repartidor ON public.encomienda;
CREATE POLICY pol_encomienda_repartidor ON public.encomienda
    FOR SELECT
    TO rol_repartidor
    USING (
        EXISTS (
            SELECT 1 FROM public.asignacion_ruta ar
            JOIN seguridad.usuario_repartidor ur ON ur.id_repartidor = ar.id_repartidor
            WHERE ar.id_encomienda = encomienda.id_encomienda
              AND ur.usuario = CURRENT_USER
        )
    );

-- 4.2. Políticas para evento_rastreo
DROP POLICY IF EXISTS pol_evento_admin_auditor ON public.evento_rastreo;
CREATE POLICY pol_evento_admin_auditor ON public.evento_rastreo
    FOR ALL
    TO rol_dba, rol_gerencia, rol_auditor, postgres
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS pol_evento_sucursal ON public.evento_rastreo;
CREATE POLICY pol_evento_sucursal ON public.evento_rastreo
    FOR ALL
    TO rol_encargado_sucursal, rol_recepcionista
    USING (
        seguridad.usuario_tiene_sucursal(id_sucursal)
    )
    WITH CHECK (
        seguridad.usuario_tiene_sucursal(id_sucursal)
    );

DROP POLICY IF EXISTS pol_evento_repartidor ON public.evento_rastreo;
CREATE POLICY pol_evento_repartidor ON public.evento_rastreo
    FOR INSERT
    TO rol_repartidor
    WITH CHECK (true);

-- ---------------------------------------------------------------------
-- 5. CIFRADO CRIPTOGRÁFICO CON EXTENSIÓN PGCRYPTO
-- ---------------------------------------------------------------------

-- Tabla de tokens y pines de entrega con hash criptográfico con salt (Blowfish)
CREATE TABLE IF NOT EXISTS seguridad.encomienda_token_seguro (
    id_encomienda INT PRIMARY KEY REFERENCES public.encomienda(id_encomienda) ON DELETE CASCADE,
    pin_hash TEXT NOT NULL,
    referencia_pago_cifrada BYTEA,
    fecha_generacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Función para generar y hashear PIN de retiro seguro
CREATE OR REPLACE FUNCTION seguridad.fn_registrar_pin_entrega(
    p_id_encomienda INT,
    p_pin_plano TEXT,
    p_referencia_bancaria TEXT,
    p_clave_secreta TEXT
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO seguridad.encomienda_token_seguro (
        id_encomienda, 
        pin_hash, 
        referencia_pago_cifrada
    ) VALUES (
        p_id_encomienda,
        crypt(p_pin_plano, gen_salt('bf', 8)), -- Hash Blowfish irreversible con salting
        pgp_sym_encrypt(p_referencia_bancaria, p_clave_secreta) -- Cifrado simétrico AES
    )
    ON CONFLICT (id_encomienda) DO UPDATE SET
        pin_hash = crypt(p_pin_plano, gen_salt('bf', 8)),
        referencia_pago_cifrada = pgp_sym_encrypt(p_referencia_bancaria, p_clave_secreta),
        fecha_generacion = CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Función para validar PIN de retiro presentado por el cliente en ventanilla
CREATE OR REPLACE FUNCTION seguridad.fn_validar_pin_entrega(
    p_id_encomienda INT,
    p_pin_ingresado TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
    v_hash_almacenado TEXT;
BEGIN
    SELECT pin_hash INTO v_hash_almacenado
    FROM seguridad.encomienda_token_seguro
    WHERE id_encomienda = p_id_encomienda;

    IF v_hash_almacenado IS NULL THEN
        RETURN FALSE;
    END IF;

    -- Comprobación criptográfica del hash
    RETURN (v_hash_almacenado = crypt(p_pin_ingresado, v_hash_almacenado));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------------------------------------------------------------------
-- 6. CUENTAS NOMINALES Y MAPEO DE SUCURSAL PARA PRUEBAS
-- ---------------------------------------------------------------------
DO $crear_usuarios$
BEGIN
    -- 1. Operador de San Salvador (Sucursal 1)
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_operador_ss') THEN
        CREATE USER usr_operador_ss WITH PASSWORD 'OperadorSS123!' IN ROLE rol_recepcionista INHERIT;
    END IF;

    -- 2. Operador de Santa Ana (Sucursal 2)
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_operador_sa') THEN
        CREATE USER usr_operador_sa WITH PASSWORD 'OperadorSA123!' IN ROLE rol_recepcionista INHERIT;
    END IF;

    -- 3. Auditor Fiscal
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_auditor_fiscal') THEN
        CREATE USER usr_auditor_fiscal WITH PASSWORD 'AuditorFiscal123!' IN ROLE rol_auditor INHERIT;
    END IF;

    -- Asignar usuarios a sus sucursales correspondientes
    INSERT INTO seguridad.usuario_sucursal (usuario, id_sucursal)
    VALUES 
        ('usr_operador_ss', 1), -- Sucursal San Salvador
        ('usr_operador_sa', 2)  -- Sucursal Santa Ana
    ON CONFLICT DO NOTHING;
END $crear_usuarios$;
