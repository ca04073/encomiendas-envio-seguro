-- =====================================================================
-- 00_setup_cluster.sql: Configuración de Roles de Infraestructura y Extensiones
-- =====================================================================

-- 1. Crear extensiones requeridas para observabilidad y seguridad
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pgaudit;

-- 2. Crear usuario de replicación para streaming y pg_basebackup
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'replicator') THEN
        CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'ReplPasswordSeguro123';
        RAISE NOTICE 'Rol de replicación replicator creado satisfactoriamente.';
    END IF;
END $$;
