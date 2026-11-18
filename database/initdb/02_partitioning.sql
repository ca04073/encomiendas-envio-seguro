-- =====================================================================
-- 02_partitioning.sql: Particionamiento Declarativo por Rango (RANGE)
-- Proyecto: Sistema de Encomiendas "Envío Seguro" (ADB135)
-- Tabla Objetivo: evento_rastreo (Series temporales de alto volumen)
-- Columna de Partición: fecha_hora (TIMESTAMP)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. CREACIÓN DE PARTICIONES MENSUALES Y TRIMESTRALES
-- ---------------------------------------------------------------------

-- Particiones mensuales para el primer trimestre de 2026 (datos semilla)
CREATE TABLE IF NOT EXISTS evento_rastreo_2026_01 PARTITION OF evento_rastreo
    FOR VALUES FROM ('2026-01-01 00:00:00') TO ('2026-02-01 00:00:00');

CREATE TABLE IF NOT EXISTS evento_rastreo_2026_02 PARTITION OF evento_rastreo
    FOR VALUES FROM ('2026-02-01 00:00:00') TO ('2026-03-01 00:00:00');

CREATE TABLE IF NOT EXISTS evento_rastreo_2026_03 PARTITION OF evento_rastreo
    FOR VALUES FROM ('2026-03-01 00:00:00') TO ('2026-04-01 00:00:00');

-- Particiones trimestrales para el resto del año 2026
CREATE TABLE IF NOT EXISTS evento_rastreo_2026_q2 PARTITION OF evento_rastreo
    FOR VALUES FROM ('2026-04-01 00:00:00') TO ('2026-07-01 00:00:00');

CREATE TABLE IF NOT EXISTS evento_rastreo_2026_q3 PARTITION OF evento_rastreo
    FOR VALUES FROM ('2026-07-01 00:00:00') TO ('2026-10-01 00:00:00');

CREATE TABLE IF NOT EXISTS evento_rastreo_2026_q4 PARTITION OF evento_rastreo
    FOR VALUES FROM ('2026-10-01 00:00:00') TO ('2027-01-01 00:00:00');

-- Partición de proyección futura para el primer trimestre de 2027
CREATE TABLE IF NOT EXISTS evento_rastreo_2027_q1 PARTITION OF evento_rastreo
    FOR VALUES FROM ('2027-01-01 00:00:00') TO ('2027-04-01 00:00:00');

-- Partición por defecto (captura cualquier fecha fuera de los rangos definidos)
CREATE TABLE IF NOT EXISTS evento_rastreo_default PARTITION OF evento_rastreo DEFAULT;

-- ---------------------------------------------------------------------
-- 2. FUNCIÓN DBA: GENERACIÓN AUTOMÁTICA DE PARTICIONES MENSUALES
-- Permite al administrador o a un job programado crear particiones
-- futuras de forma segura y sin interrupciones de servicio.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_crear_particion_evento(p_anio INT, p_mes INT)
RETURNS TEXT AS $$
DECLARE
    v_nombre_particion TEXT;
    v_fecha_inicio DATE;
    v_fecha_fin DATE;
    v_sql TEXT;
BEGIN
    v_fecha_inicio := MAKE_DATE(p_anio, p_mes, 1);
    v_fecha_fin    := v_fecha_inicio + INTERVAL '1 month';
    v_nombre_particion := FORMAT('evento_rastreo_%s_%s', p_anio, LPAD(p_mes::TEXT, 2, '0'));

    IF EXISTS (SELECT 1 FROM pg_class WHERE relname = v_nombre_particion) THEN
        RETURN FORMAT('La partición %s ya existe.', v_nombre_particion);
    END IF;

    v_sql := FORMAT(
        'CREATE TABLE IF NOT EXISTS %I PARTITION OF evento_rastreo ' ||
        'FOR VALUES FROM (%L) TO (%L);',
        v_nombre_particion, v_fecha_inicio, v_fecha_fin
    );

    EXECUTE v_sql;
    RETURN FORMAT('Partición %s creada exitosamente para rango [%s - %s).', 
                  v_nombre_particion, v_fecha_inicio, v_fecha_fin);
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------
-- 3. AUDITORÍA Y VERIFICACIÓN DE PARTICIONES ACTIVAS
-- ---------------------------------------------------------------------
DO $$
DECLARE
    v_total_particiones INT;
BEGIN
    SELECT COUNT(*) INTO v_total_particiones
    FROM pg_inherits
    WHERE inhparent = 'evento_rastreo'::regclass;

    RAISE NOTICE '02_partitioning.sql: % particiones configuradas para evento_rastreo.', v_total_particiones;
END $$;
