-- =====================================================================
-- 03_triggers_views.sql: Triggers de Negocio y Vistas Analíticas
-- Proyecto: Sistema de Encomiendas "Envío Seguro" (ADB135)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. TRIGGER: Sincronización Automática del Estado de la Encomienda
-- Cuando se registra un nuevo evento de rastreo, la encomienda asociada
-- actualiza de inmediato su 'id_estado' al nuevo estado registrado.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_tr_actualizar_estado_encomienda()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE encomienda
    SET id_estado = NEW.id_estado
    WHERE id_encomienda = NEW.id_encomienda;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_actualizar_estado_encomienda ON evento_rastreo;
CREATE TRIGGER tr_actualizar_estado_encomienda
    AFTER INSERT ON evento_rastreo
    FOR EACH ROW
    EXECUTE FUNCTION fn_tr_actualizar_estado_encomienda();

-- ---------------------------------------------------------------------
-- 2. TRIGGER: Validación Cronológica de Eventos de Rastreo
-- Previene errores lógicos donde un evento de rastreo tenga una fecha_hora
-- anterior a la creación de la encomienda asociada.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_tr_validar_fecha_evento()
RETURNS TRIGGER AS $$
DECLARE
    v_fecha_recepcion TIMESTAMP;
BEGIN
    SELECT fecha_recepcion INTO v_fecha_recepcion
    FROM encomienda
    WHERE id_encomienda = NEW.id_encomienda;

    IF NEW.fecha_hora < v_fecha_recepcion THEN
        RAISE EXCEPTION 'Violación cronológica: La fecha del evento (%) no puede ser anterior a la recepción de la encomienda (%).',
            NEW.fecha_hora, v_fecha_recepcion;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_validar_fecha_evento ON evento_rastreo;
CREATE TRIGGER tr_validar_fecha_evento
    BEFORE INSERT OR UPDATE ON evento_rastreo
    FOR EACH ROW
    EXECUTE FUNCTION fn_tr_validar_fecha_evento();

-- ---------------------------------------------------------------------
-- 3. TRIGGER: Cierre Automático de Incidencias
-- Al cambiar el estado de una incidencia a 'Resuelta' o 'Cerrada',
-- asigna automáticamente la fecha de resolución si no fue proporcionada.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_tr_cierre_incidencia()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.estado IN ('Resuelta', 'Cerrada') AND NEW.fecha_resolucion IS NULL THEN
        NEW.fecha_resolucion := CURRENT_DATE;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_cierre_incidencia ON incidencia;
CREATE TRIGGER tr_cierre_incidencia
    BEFORE INSERT OR UPDATE OF estado ON incidencia
    FOR EACH ROW
    EXECUTE FUNCTION fn_tr_cierre_incidencia();

-- =====================================================================
-- SECCIÓN B: VISTAS OPERATIVAS Y ANALÍTICAS
-- =====================================================================

-- ---------------------------------------------------------------------
-- VISTA 1: Encomiendas Activas en Tránsito con Último Evento
-- Utilizada por la mesa de ayuda y monitoreo de operaciones.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_encomiendas_activas AS
WITH ultimo_evento AS (
    SELECT DISTINCT ON (id_encomienda)
        id_encomienda,
        id_estado,
        id_sucursal,
        fecha_hora,
        observacion
    FROM evento_rastreo
    ORDER BY id_encomienda, fecha_hora DESC
)
SELECT 
    e.id_encomienda,
    g.numero_guia,
    c_rem.nombres || ' ' || COALESCE(c_rem.apellidos, '') AS remitente,
    c_dest.nombres || ' ' || COALESCE(c_dest.apellidos, '') AS destinatario,
    s_orig.nombre AS sucursal_origen,
    s_dest.nombre AS sucursal_destino,
    ee.nombre AS estado_actual,
    ue.fecha_hora AS fecha_ultimo_evento,
    s_actual.nombre AS sucursal_actual,
    ue.observacion AS observacion_ultimo_evento,
    g.tarifa,
    g.tipo_cobro
FROM encomienda e
JOIN guia_envio g ON g.id_encomienda = e.id_encomienda
JOIN cliente c_rem ON c_rem.id_cliente = e.id_remitente
JOIN cliente c_dest ON c_dest.id_cliente = e.id_destinatario
JOIN sucursal s_orig ON s_orig.id_sucursal = e.id_sucursal_origen
JOIN sucursal s_dest ON s_dest.id_sucursal = e.id_sucursal_destino
JOIN estado_encomienda ee ON ee.id_estado = e.id_estado
LEFT JOIN ultimo_evento ue ON ue.id_encomienda = e.id_encomienda
LEFT JOIN sucursal s_actual ON s_actual.id_sucursal = ue.id_sucursal
WHERE ee.nombre NOT IN ('Entregada', 'Cancelada');

-- ---------------------------------------------------------------------
-- VISTA 2: Métricas de Facturación Electrónica (DTE) por Sucursal
-- Utilizada para auditoría fiscal y control contable.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_metricas_facturacion_sucursal AS
SELECT 
    s.id_sucursal,
    s.nombre AS sucursal,
    s.codigo_establecimiento,
    COUNT(d.id_documento) AS total_dtes_emitidos,
    COALESCE(SUM(d.total_pagar), 0.00) AS monto_total_facturado,
    COALESCE(SUM(d.iva), 0.00) AS total_iva_retenido,
    ROUND(COALESCE(AVG(d.total_pagar), 0.00), 2) AS ticket_promedio
FROM sucursal s
LEFT JOIN empleado em ON em.id_sucursal = s.id_sucursal
LEFT JOIN guia_envio g ON g.id_empleado = em.id_empleado
LEFT JOIN documento_dte d ON d.id_guia = g.id_guia
GROUP BY s.id_sucursal, s.nombre, s.codigo_establecimiento;
