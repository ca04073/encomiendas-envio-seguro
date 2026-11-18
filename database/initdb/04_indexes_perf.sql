-- =====================================================================
-- 04_indexes_perf.sql: Índices de Alto Rendimiento y Optimización DBA
-- Proyecto: Sistema de Encomiendas "Envío Seguro" (ADB135)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. ÍNDICES B-TREE COMPUESTOS PARA BÚSQUEDAS DE ALTA CONCURRENCIA
-- ---------------------------------------------------------------------

-- Búsqueda de guías por fecha de emisión y tipo de cobro
CREATE INDEX IF NOT EXISTS idx_guia_envio_emision
    ON guia_envio (fecha_emision, tipo_cobro);

-- Consulta de verificación de pagos por guía y estado
CREATE INDEX IF NOT EXISTS idx_pago_guia_estado
    ON pago (id_guia, estado_pago);

-- Consulta fiscal rápida por UUID de Factura Electrónica (DTE)
CREATE UNIQUE INDEX IF NOT EXISTS idx_documento_dte_uuid
    ON documento_dte (codigo_generacion);

-- Búsqueda rápida de clientes en ventanilla por documento de identidad
CREATE INDEX IF NOT EXISTS idx_cliente_identificacion
    ON cliente (dui, nit);

-- Búsqueda de rutas activas por par origen-destino
CREATE INDEX IF NOT EXISTS idx_ruta_origen_destino
    ON ruta (id_sucursal_origen, id_sucursal_destino);

-- ---------------------------------------------------------------------
-- 2. ÍNDICES PARCIALES (PARTIAL INDEXES) PARA FILTRADO EFICIENTE
-- Reducen radicalmente el tamaño del índice en disco al indexar
-- únicamente el subconjunto de filas sobre las que opera el negocio diario.
-- ---------------------------------------------------------------------

-- Índice parcial: Pagos pendientes de liquidar (ignora los miles de pagos ya cobrados)
CREATE INDEX IF NOT EXISTS idx_pago_pendientes_parcial
    ON pago (id_pago, id_guia, monto, fecha_pago)
    WHERE estado_pago = 'Pendiente';

-- Índice parcial: Incidencias activas que requieren atención operativa
CREATE INDEX IF NOT EXISTS idx_incidencias_activas_parcial
    ON incidencia (id_incidencia, id_encomienda, prioridad, fecha_reporte)
    WHERE estado IN ('Abierta', 'En proceso');

-- Índice parcial: Asignaciones de ruta en curso (sin fecha de llegada aún)
CREATE INDEX IF NOT EXISTS idx_asignaciones_en_ruta_parcial
    ON asignacion_ruta (id_asignacion, id_ruta, id_repartidor, fecha_salida)
    WHERE fecha_llegada IS NULL;

-- ---------------------------------------------------------------------
-- 3. ESTADÍSTICAS Y MANTENIMIENTO INICIAL
-- Forzar la recolección de estadísticas del planificador de PostgreSQL
-- ---------------------------------------------------------------------
ANALYZE guia_envio;
ANALYZE pago;
ANALYZE documento_dte;
ANALYZE cliente;
ANALYZE incidencia;
ANALYZE evento_rastreo;
