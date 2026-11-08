-- =====================================================================
-- ENVIO-SEGURO | Fase 07: carga de datos de prueba (DML)
-- PostgreSQL 17
--
-- Ejecutar conectado a envio_seguro como postgres.
-- Genera datos ficticios para las 20 tablas del esquema original.
--
-- Volumen objetivo: 5,690 registros en total.
--   1 agencia, 14 sucursales, 56 empleados, 28 repartidores,
--   300 clientes, 8 estados, 500 encomiendas, 500 guias,
--   50 rutas, 500 asignaciones, 2,000 eventos,
--   5 metodos de pago, 400 pagos, 5 tipos DTE, 5 estados DTE,
--   10 servicios, 400 documentos DTE, 800 detalles,
--   8 tipos de incidencia y 100 incidencias.
--
-- IMPORTANTE:
--   - No elimina ni trunca datos existentes.
--   - Si detecta datos previos en las tablas de negocio, aborta.
--   - NO ejecutar sobre la base actual ya poblada; sirve para una carga limpia.
--   - Los registros son ficticios; no representan personas reales.
--   - La ubicacion final del destinatario no se almacena.
-- =====================================================================

\encoding UTF8
\set ON_ERROR_STOP on

BEGIN;

-- Evita mezclar silenciosamente esta carga con datos preexistentes.
DO $$
DECLARE
    v_total BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_total
    FROM (
        SELECT 1 FROM public.agencia
        UNION ALL SELECT 1 FROM public.sucursal
        UNION ALL SELECT 1 FROM public.empleado
        UNION ALL SELECT 1 FROM public.repartidor
        UNION ALL SELECT 1 FROM public.cliente
        UNION ALL SELECT 1 FROM public.estado_encomienda
        UNION ALL SELECT 1 FROM public.encomienda
        UNION ALL SELECT 1 FROM public.guia_envio
        UNION ALL SELECT 1 FROM public.ruta
        UNION ALL SELECT 1 FROM public.asignacion_ruta
        UNION ALL SELECT 1 FROM public.evento_rastreo
        UNION ALL SELECT 1 FROM public.metodo_pago
        UNION ALL SELECT 1 FROM public.pago
        UNION ALL SELECT 1 FROM public.tipo_dte
        UNION ALL SELECT 1 FROM public.estado_dte
        UNION ALL SELECT 1 FROM public.servicio_tarifa
        UNION ALL SELECT 1 FROM public.documento_dte
        UNION ALL SELECT 1 FROM public.detalle_dte
        UNION ALL SELECT 1 FROM public.tipo_incidencia
        UNION ALL SELECT 1 FROM public.incidencia
    ) AS existentes;

    IF v_total > 0 THEN
        RAISE EXCEPTION
            'Carga cancelada: ya existen % registros en las tablas de negocio. No se insertaron datos.',
            v_total;
    END IF;
END
$$;

-- ---------------------------------------------------------------------
-- 1. Agencia y 14 sucursales (una por departamento)
-- ---------------------------------------------------------------------

INSERT INTO public.agencia
    (nombre, nit, nrc, actividad_economica, telefono, correo)
VALUES
    ('Envio Seguro, S.A. de C.V.', '0614-071126-101-1', '345678-9',
     'Servicios de mensajeria y transporte de encomiendas',
     '22000000', 'contacto@envioseguro.test');

INSERT INTO public.sucursal
    (id_agencia, codigo_establecimiento, nombre, direccion,
     municipio, departamento, telefono, activa)
SELECT
    (SELECT id_agencia FROM public.agencia
     WHERE nit = '0614-071126-101-1'),
    LPAD(g.n::TEXT, 4, '0'),
    'Sucursal ' || g.departamento,
    'Avenida Principal, local ' || g.n,
    g.municipio,
    g.departamento,
    '22' || LPAD(g.n::TEXT, 6, '0'),
    TRUE
FROM (VALUES
    (1, 'San Salvador', 'San Salvador'),
    (2, 'Santa Ana', 'Santa Ana'),
    (3, 'San Miguel', 'San Miguel'),
    (4, 'Nueva San Salvador', 'La Libertad'),
    (5, 'Zacatecoluca', 'La Paz'),
    (6, 'Cojutepeque', 'Cuscatlan'),
    (7, 'Sensuntepeque', 'Cabanas'),
    (8, 'Chalatenango', 'Chalatenango'),
    (9, 'Usulutan', 'Usulutan'),
    (10, 'San Francisco Gotera', 'Morazan'),
    (11, 'La Union', 'La Union'),
    (12, 'Ahuachapan', 'Ahuachapan'),
    (13, 'Sonsonate', 'Sonsonate'),
    (14, 'San Vicente', 'San Vicente')
) AS g(n, municipio, departamento)
ORDER BY g.n;

-- ---------------------------------------------------------------------
-- 2. Empleados: 4 por sucursal (56)
-- ---------------------------------------------------------------------

INSERT INTO public.empleado
    (id_sucursal, nombres, apellidos, dui, cargo, telefono, correo,
     fecha_contratacion, activo)
SELECT
    s.id_sucursal,
    'Empleado' || LPAD(x.n::TEXT, 2, '0'),
    'Sucursal' || LPAD(s.id_sucursal::TEXT, 2, '0'),
    LPAD((s.id_sucursal * 100 + x.n)::TEXT, 8, '0') || '-0',
    CASE x.n
        WHEN 1 THEN 'Encargado'
        WHEN 2 THEN 'Recepcionista'
        WHEN 3 THEN 'Auxiliar operativo'
        ELSE 'Administrativo'
    END,
    '70' || LPAD((s.id_sucursal * 100 + x.n)::TEXT, 6, '0'),
    'empleado' || LPAD(s.id_sucursal::TEXT, 2, '0') || '_' ||
        x.n || '@envioseguro.test',
    DATE '2022-01-01' + ((s.id_sucursal * 13 + x.n * 31) % 1400),
    TRUE
FROM public.sucursal AS s
CROSS JOIN generate_series(1, 4) AS x(n)
ORDER BY s.id_sucursal, x.n;

-- ---------------------------------------------------------------------
-- 3. Repartidores: 2 por sucursal (28)
-- ---------------------------------------------------------------------

INSERT INTO public.repartidor
    (id_sucursal, nombres, apellidos, dui, numero_licencia,
     tipo_vehiculo, placa, telefono, activo)
SELECT
    s.id_sucursal,
    'Repartidor' || LPAD(x.n::TEXT, 2, '0'),
    'Sucursal' || LPAD(s.id_sucursal::TEXT, 2, '0'),
    LPAD((5000 + s.id_sucursal * 10 + x.n)::TEXT, 8, '0') || '-0',
    'LIC-' || LPAD(s.id_sucursal::TEXT, 2, '0') || '-' || x.n,
    CASE WHEN x.n = 1 THEN 'Motocicleta' ELSE 'Automovil' END,
    'P' || LPAD(s.id_sucursal::TEXT, 3, '0') || x.n,
    '71' || LPAD((s.id_sucursal * 10 + x.n)::TEXT, 6, '0'),
    TRUE
FROM public.sucursal AS s
CROSS JOIN generate_series(1, 2) AS x(n)
ORDER BY s.id_sucursal, x.n;

-- ---------------------------------------------------------------------
-- 4. Clientes: 300 (datos sinteticos)
-- ---------------------------------------------------------------------

INSERT INTO public.cliente
    (tipo_contribuyente, nombres, apellidos, dui, nit, nrc, giro,
     telefono, correo, direccion, municipio, departamento)
SELECT
    CASE WHEN g.n % 4 = 0 THEN 'Contribuyente'
         ELSE 'Consumidor final' END,
    'Cliente' || LPAD(g.n::TEXT, 4, '0'),
    'Prueba' || LPAD(g.n::TEXT, 4, '0'),
    CASE WHEN g.n % 4 <> 0
         THEN LPAD((10000000 + g.n)::TEXT, 8, '0') || '-0'
         ELSE NULL END,
    CASE WHEN g.n % 4 = 0
         THEN '0614-' || LPAD((100000 + g.n)::TEXT, 6, '0') || '-101-0'
         ELSE NULL END,
    CASE WHEN g.n % 4 = 0
         THEN LPAD((100000 + g.n)::TEXT, 6, '0') || '-0'
         ELSE NULL END,
    CASE WHEN g.n % 4 = 0 THEN 'Comercio general' ELSE NULL END,
    '72' || LPAD(g.n::TEXT, 6, '0'),
    'cliente' || LPAD(g.n::TEXT, 4, '0') || '@envioseguro.test',
    'Calle de prueba numero ' || g.n,
    (ARRAY[
        'San Salvador','Santa Ana','San Miguel','Nueva San Salvador',
        'Zacatecoluca','Cojutepeque','Sensuntepeque','Chalatenango',
        'Usulutan','San Francisco Gotera','La Union','Ahuachapan',
        'Sonsonate','San Vicente'
    ])[((g.n - 1) % 14) + 1],
    (ARRAY[
        'San Salvador','Santa Ana','San Miguel','La Libertad','La Paz',
        'Cuscatlan','Cabanas','Chalatenango','Usulutan','Morazan',
        'La Union','Ahuachapan','Sonsonate','San Vicente'
    ])[((g.n - 1) % 14) + 1]
FROM generate_series(1, 300) AS g(n);

-- ---------------------------------------------------------------------
-- 5. Catalogo de estados de encomienda
-- ---------------------------------------------------------------------

INSERT INTO public.estado_encomienda (nombre, descripcion)
VALUES
    ('Recibida', 'Encomienda recibida en la sucursal de origen.'),
    ('En transito', 'Encomienda trasladandose entre sucursales.'),
    ('En sucursal destino', 'Encomienda recibida en sucursal de destino.'),
    ('En reparto', 'Encomienda asignada para distribucion local.'),
    ('Entregada', 'Encomienda entregada al destinatario.'),
    ('No entregada', 'No fue posible completar la entrega.'),
    ('En incidencia', 'Encomienda con incidencia operativa.'),
    ('Cancelada', 'Encomienda cancelada.');

-- ---------------------------------------------------------------------
-- 6. Encomiendas: 500 y sus guias (1:1)
-- ---------------------------------------------------------------------

INSERT INTO public.encomienda
    (id_remitente, id_destinatario, id_sucursal_origen,
     id_sucursal_destino, id_estado, descripcion, peso_kg,
     valor_declarado, fecha_recepcion)
SELECT
    c1.id_cliente,
    c2.id_cliente,
    so.id_sucursal,
    sd.id_sucursal,
    (
        SELECT ee.id_estado
        FROM public.estado_encomienda AS ee
        WHERE ee.nombre = CASE
            WHEN g.n % 20 = 0 THEN 'En incidencia'
            WHEN g.n % 10 = 0 THEN 'Entregada'
            WHEN g.n % 7 = 0 THEN 'En reparto'
            WHEN g.n % 5 = 0 THEN 'En sucursal destino'
            WHEN g.n % 3 = 0 THEN 'En transito'
            ELSE 'Recibida'
        END
    ),
    'PAQUETE-PRUEBA-' || LPAD(g.n::TEXT, 4, '0'),
    (1 + (g.n % 250) / 10.0)::NUMERIC(8,2),
    (25 + (g.n % 100) * 3.5)::NUMERIC(10,2),
    TIMESTAMP '2026-01-01 08:00:00' + (g.n * INTERVAL '2 hours')
FROM generate_series(1, 500) AS g(n)
JOIN public.cliente AS c1
  ON c1.correo = 'cliente' || LPAD((((g.n - 1) % 300) + 1)::TEXT, 4, '0')
                 || '@envioseguro.test'
JOIN public.cliente AS c2
  ON c2.correo = 'cliente' || LPAD((((g.n + 36) % 300) + 1)::TEXT, 4, '0')
                 || '@envioseguro.test'
JOIN public.sucursal AS so
  ON so.codigo_establecimiento = LPAD((((g.n - 1) % 14) + 1)::TEXT, 4, '0')
JOIN public.sucursal AS sd
  ON sd.codigo_establecimiento =
     LPAD(((g.n % 14) + 1)::TEXT, 4, '0');

INSERT INTO public.guia_envio
    (id_encomienda, id_empleado, numero_guia, fecha_emision,
     tipo_cobro, tarifa)
SELECT
    e.id_encomienda,
    em.id_empleado,
    'ES-' || LPAD(e.id_encomienda::TEXT, 10, '0'),
    e.fecha_recepcion + INTERVAL '10 minutes',
    CASE WHEN e.id_encomienda % 2 = 0
         THEN 'Remitente' ELSE 'Contra entrega' END,
    (5 + (e.id_encomienda % 20) * 0.75)::NUMERIC(10,2)
FROM public.encomienda AS e
JOIN public.empleado AS em
  ON em.id_sucursal = e.id_sucursal_origen
 AND em.correo = 'empleado' ||
     LPAD(e.id_sucursal_origen::TEXT, 2, '0') || '_2@envioseguro.test';

-- ---------------------------------------------------------------------
-- 7. Rutas: 50 pares origen-destino distintos
-- ---------------------------------------------------------------------

INSERT INTO public.ruta
    (id_sucursal_origen, id_sucursal_destino, nombre,
     distancia_km, tiempo_estimado_min)
SELECT
    so.id_sucursal,
    sd.id_sucursal,
    'Ruta-' || LPAD(g.n::TEXT, 3, '0'),
    (15 + (g.n * 7 % 280))::NUMERIC(7,2),
    30 + (g.n * 11 % 300)
FROM generate_series(1, 50) AS g(n)
JOIN public.sucursal AS so
  ON so.codigo_establecimiento = LPAD((((g.n - 1) % 14) + 1)::TEXT, 4, '0')
JOIN public.sucursal AS sd
  ON sd.codigo_establecimiento = LPAD(((g.n % 14) + 1)::TEXT, 4, '0');

-- ---------------------------------------------------------------------
-- 8. Asignaciones: una por encomienda
-- ---------------------------------------------------------------------

INSERT INTO public.asignacion_ruta
    (id_ruta, id_repartidor, id_encomienda, fecha_salida,
     fecha_llegada, observaciones)
SELECT
    r.id_ruta,
    rep.id_repartidor,
    e.id_encomienda,
    e.fecha_recepcion + INTERVAL '1 hour',
    CASE WHEN e.id_encomienda % 6 = 0 THEN NULL
         ELSE e.fecha_recepcion + INTERVAL '5 hours' END,
    'Asignacion de prueba ' || e.id_encomienda
FROM public.encomienda AS e
JOIN LATERAL (
    SELECT r0.id_ruta
    FROM public.ruta AS r0
    WHERE r0.id_sucursal_origen = e.id_sucursal_origen
      AND r0.id_sucursal_destino = e.id_sucursal_destino
    ORDER BY r0.id_ruta
    LIMIT 1
) AS r ON TRUE
JOIN public.repartidor AS rep
  ON rep.id_sucursal = e.id_sucursal_origen
 AND rep.id_repartidor = (
     SELECT MIN(rep2.id_repartidor)
     FROM public.repartidor AS rep2
     WHERE rep2.id_sucursal = e.id_sucursal_origen
 );

-- ---------------------------------------------------------------------
-- 9. Eventos de rastreo: cuatro eventos por encomienda (2,000)
-- ---------------------------------------------------------------------

INSERT INTO public.evento_rastreo
    (id_encomienda, id_estado, id_sucursal, id_empleado,
     fecha_hora, observacion)
SELECT
    e.id_encomienda,
    (
        SELECT ee.id_estado
        FROM public.estado_encomienda AS ee
        WHERE ee.nombre = CASE x.paso
            WHEN 1 THEN 'Recibida'
            WHEN 2 THEN 'En transito'
            WHEN 3 THEN 'En sucursal destino'
            ELSE CASE WHEN e.id_encomienda % 5 = 0
                      THEN 'Entregada' ELSE 'En reparto' END
        END
    ),
    CASE WHEN x.paso <= 2
         THEN e.id_sucursal_origen
         ELSE e.id_sucursal_destino END,
    em.id_empleado,
    e.fecha_recepcion + (x.paso * INTERVAL '1 hour'),
    CASE x.paso
        WHEN 1 THEN 'Recepcion registrada.'
        WHEN 2 THEN 'Salida hacia sucursal destino.'
        WHEN 3 THEN 'Recepcion en sucursal destino.'
        ELSE 'Inicio de distribucion local.'
    END
FROM public.encomienda AS e
CROSS JOIN generate_series(1, 4) AS x(paso)
JOIN public.empleado AS em
  ON em.id_sucursal = CASE WHEN x.paso <= 2
                           THEN e.id_sucursal_origen
                           ELSE e.id_sucursal_destino END
 AND em.cargo = 'Recepcionista';

-- ---------------------------------------------------------------------
-- 10. Metodos de pago y pagos (400)
-- ---------------------------------------------------------------------

INSERT INTO public.metodo_pago (nombre, descripcion)
VALUES
    ('Efectivo', 'Pago en efectivo.'),
    ('Tarjeta', 'Pago con tarjeta de debito o credito.'),
    ('Transferencia', 'Transferencia bancaria.'),
    ('Billetera digital', 'Pago mediante billetera digital.'),
    ('Pago contra entrega', 'Cobro al momento de la entrega.');

-- Un pago por guia; se distribuyen los cinco metodos existentes
-- sin asumir que sus valores identity comienzan en 1.
WITH guias_seleccionadas AS (
    SELECT
        g.id_guia,
        e.id_remitente,
        g.id_empleado,
        g.tarifa,
        g.fecha_emision,
        ROW_NUMBER() OVER (
            ORDER BY e.fecha_recepcion, e.id_encomienda
        ) AS rn
    FROM public.guia_envio AS g
    JOIN public.encomienda AS e
      ON e.id_encomienda = g.id_encomienda
    ORDER BY e.fecha_recepcion, e.id_encomienda
    LIMIT 400
),
metodos AS (
    SELECT
        mp.id_metodo_pago,
        ROW_NUMBER() OVER (ORDER BY mp.id_metodo_pago) AS rn,
        COUNT(*) OVER () AS total_metodos
    FROM public.metodo_pago AS mp
)
INSERT INTO public.pago
    (id_guia, id_cliente_pagador, id_metodo_pago, id_empleado,
     monto, fecha_pago, estado_pago, referencia)
SELECT
    gs.id_guia,
    gs.id_remitente,
    m.id_metodo_pago,
    gs.id_empleado,
    GREATEST(gs.tarifa, 0.01),
    gs.fecha_emision,
    CASE
        WHEN gs.rn % 20 = 0 THEN 'Pendiente'
        WHEN gs.rn % 25 = 0 THEN 'Anulado'
        ELSE 'Pagado'
    END,
    'REF-ENV-' || gs.id_guia
FROM guias_seleccionadas AS gs
JOIN metodos AS m
  ON m.rn = ((gs.rn - 1) % m.total_metodos) + 1;

-- ---------------------------------------------------------------------
-- 11. Catalogos DTE y servicios
-- ---------------------------------------------------------------------

INSERT INTO public.tipo_dte (codigo, nombre)
VALUES
    ('01', 'Factura'),
    ('03', 'Comprobante de credito fiscal'),
    ('04', 'Nota de remision'),
    ('05', 'Nota de credito'),
    ('06', 'Nota de debito');

INSERT INTO public.estado_dte (nombre, descripcion)
VALUES
    ('Borrador', 'Documento en preparacion.'),
    ('Transmitido', 'Documento enviado a la autoridad fiscal.'),
    ('Aceptado', 'Documento aceptado.'),
    ('Rechazado', 'Documento rechazado.'),
    ('Anulado', 'Documento anulado.');

INSERT INTO public.servicio_tarifa
    (nombre, descripcion, precio_base, aplica_iva)
VALUES
    ('Envio local', 'Servicio de envio dentro del mismo municipio.', 4.50, TRUE),
    ('Envio departamental', 'Servicio de envio dentro del departamento.', 6.50, TRUE),
    ('Envio nacional', 'Servicio de envio entre departamentos.', 8.50, TRUE),
    ('Manejo especial', 'Manejo especial de encomienda.', 3.00, TRUE),
    ('Seguro basico', 'Cobertura basica declarada.', 2.00, TRUE),
    ('Entrega prioritaria', 'Servicio de entrega prioritaria.', 5.00, TRUE),
    ('Recoleccion', 'Recoleccion programada.', 2.50, TRUE),
    ('Embalaje', 'Servicio de embalaje.', 1.75, TRUE),
    ('Almacenamiento', 'Almacenamiento temporal.', 1.25, TRUE),
    ('Servicio exento', 'Concepto de prueba sin IVA.', 0.00, FALSE);

-- ---------------------------------------------------------------------
-- 12. Documentos DTE: 400 (uno por cada guia con pago)
-- ---------------------------------------------------------------------

WITH guias_seleccionadas AS (
    SELECT
        g.id_guia,
        e.id_destinatario,
        g.fecha_emision,
        g.tarifa,
        ROW_NUMBER() OVER (
            ORDER BY e.fecha_recepcion, e.id_encomienda
        ) AS rn
    FROM public.pago AS p
    JOIN public.guia_envio AS g
      ON g.id_guia = p.id_guia
    JOIN public.encomienda AS e
      ON e.id_encomienda = g.id_encomienda
),
tipos AS (
    SELECT
        id_tipo_dte,
        ROW_NUMBER() OVER (ORDER BY id_tipo_dte) AS rn
    FROM public.tipo_dte
),
estados AS (
    SELECT
        id_estado_dte,
        ROW_NUMBER() OVER (ORDER BY id_estado_dte) AS rn
    FROM public.estado_dte
)
INSERT INTO public.documento_dte
    (id_guia, id_tipo_dte, id_estado_dte, id_cliente_receptor,
     codigo_generacion, numero_control, fecha_emision, hora_emision,
     ambiente, total_gravado, iva, total_pagar, sello_recepcion)
SELECT
    gs.id_guia,
    t.id_tipo_dte,
    es.id_estado_dte,
    gs.id_destinatario,
    gen_random_uuid(),
    'DTE-01-' || LPAD(gs.rn::TEXT, 22, '0'),
    gs.fecha_emision::DATE,
    gs.fecha_emision::TIME,
    '00',
    ROUND(gs.tarifa, 2),
    ROUND(gs.tarifa * 0.13, 2),
    ROUND(gs.tarifa + ROUND(gs.tarifa * 0.13, 2), 2),
    NULL
FROM guias_seleccionadas AS gs
JOIN tipos AS t
  ON t.rn = ((gs.rn - 1) % 5) + 1
JOIN estados AS es
  ON es.rn = ((gs.rn - 1) % 5) + 1
ORDER BY gs.rn;

-- ---------------------------------------------------------------------
-- 13. Detalles DTE: dos por documento (800)
-- El IVA de la segunda linea absorbe el ajuste de redondeo para que
-- la suma de los detalles coincida exactamente con el encabezado.
-- ---------------------------------------------------------------------

WITH documentos AS (
    SELECT
        d.id_documento,
        d.total_gravado,
        d.iva,
        ROW_NUMBER() OVER (ORDER BY d.id_documento) AS rn
    FROM public.documento_dte AS d
),
lineas AS (
    SELECT
        id_documento,
        total_gravado,
        iva,
        rn,
        1 AS numero_linea,
        ROUND(total_gravado * 0.75, 2) AS importe
    FROM documentos

    UNION ALL

    SELECT
        id_documento,
        total_gravado,
        iva,
        rn,
        2 AS numero_linea,
        total_gravado - ROUND(total_gravado * 0.75, 2) AS importe
    FROM documentos
),
servicios AS (
    SELECT
        id_servicio,
        nombre,
        ROW_NUMBER() OVER (ORDER BY id_servicio) AS rn
    FROM public.servicio_tarifa
    WHERE aplica_iva = TRUE
)
INSERT INTO public.detalle_dte
    (id_documento, id_servicio, descripcion, cantidad,
     precio_unitario, descuento, venta_gravada, iva_item)
SELECT
    l.id_documento,
    s.id_servicio,
    s.nombre || ' - Detalle ' || l.numero_linea,
    1,
    l.importe,
    0,
    l.importe,
    CASE
        WHEN l.numero_linea = 1
            THEN ROUND(l.importe * 0.13, 2)
        ELSE l.iva - ROUND(
            ROUND(l.total_gravado * 0.75, 2) * 0.13, 2
        )
    END
FROM lineas AS l
JOIN servicios AS s
  ON s.rn = ((l.rn + l.numero_linea - 2) % 9) + 1
ORDER BY l.id_documento, l.numero_linea;

-- 14. Tipos e incidencias (100)
-- ---------------------------------------------------------------------

-- Normaliza el CHECK historicamente creado con texto mal codificado.
-- La forma ASCII 'Critica' evita problemas de codificacion del terminal.
ALTER TABLE public.incidencia
    DROP CONSTRAINT IF EXISTS ck_incidencia_prioridad;

ALTER TABLE public.incidencia
    ADD CONSTRAINT ck_incidencia_prioridad
    CHECK (prioridad IN ('Baja', 'Media', 'Alta', 'Critica'));


INSERT INTO public.tipo_incidencia (nombre, descripcion)
VALUES
    ('Direccion no localizada', 'No se logro localizar el punto indicado.'),
    ('Destinatario ausente', 'El destinatario no se encontraba disponible.'),
    ('Paquete danado', 'Se detecto dano en el embalaje o contenido.'),
    ('Demora de transporte', 'Retraso durante el traslado.'),
    ('Error de clasificacion', 'Encomienda clasificada incorrectamente.'),
    ('Problema vehicular', 'Incidente mecanico del vehiculo.'),
    ('Rechazo de entrega', 'El destinatario rechazo la encomienda.'),
    ('Otro', 'Otra incidencia operativa.');

INSERT INTO public.incidencia
    (id_encomienda, id_tipo_incidencia, id_empleado_reporta,
     id_empleado_resuelve, descripcion, fecha_reporte,
     fecha_resolucion, estado, prioridad)
SELECT
    e.id_encomienda,
    ti.id_tipo_incidencia,
    emr.id_empleado,
    CASE WHEN e.id_encomienda % 4 = 0 THEN NULL ELSE ems.id_empleado END,
    'Incidencia de prueba asociada a encomienda ' || e.id_encomienda,
    e.fecha_recepcion + INTERVAL '6 hours',
    CASE WHEN e.id_encomienda % 4 = 0 THEN NULL
         ELSE e.fecha_recepcion + INTERVAL '10 hours' END,
    CASE WHEN e.id_encomienda % 4 = 0 THEN 'Abierta'
         WHEN e.id_encomienda % 4 = 1 THEN 'En proceso'
         ELSE 'Resuelta' END,
    CASE ((e.id_encomienda - 1) % 4)
        WHEN 0 THEN 'Baja'
        WHEN 1 THEN 'Media'
        WHEN 2 THEN 'Alta'
        ELSE 'Critica'
    END
FROM public.encomienda AS e
JOIN public.tipo_incidencia AS ti
  ON ti.nombre = (ARRAY[
      'Direccion no localizada','Destinatario ausente','Paquete danado',
      'Demora de transporte','Error de clasificacion','Problema vehicular',
      'Rechazo de entrega','Otro'
  ])[((e.id_encomienda - 1) % 8) + 1]
JOIN public.empleado AS emr
  ON emr.id_sucursal = e.id_sucursal_origen
 AND emr.cargo = 'Recepcionista'
JOIN public.empleado AS ems
  ON ems.id_sucursal = e.id_sucursal_destino
 AND ems.cargo = 'Encargado'
WHERE e.id_encomienda IN (
    SELECT e2.id_encomienda
    FROM public.encomienda AS e2
    ORDER BY e2.fecha_recepcion, e2.id_encomienda
    LIMIT 100
);

COMMIT;

-- ---------------------------------------------------------------------
-- 15. Resumen de conteos: comparar con los volumenes objetivo
-- ---------------------------------------------------------------------

SELECT 'agencia' AS tabla, COUNT(*) AS registros FROM public.agencia
UNION ALL SELECT 'sucursal', COUNT(*) FROM public.sucursal
UNION ALL SELECT 'empleado', COUNT(*) FROM public.empleado
UNION ALL SELECT 'repartidor', COUNT(*) FROM public.repartidor
UNION ALL SELECT 'cliente', COUNT(*) FROM public.cliente
UNION ALL SELECT 'estado_encomienda', COUNT(*) FROM public.estado_encomienda
UNION ALL SELECT 'encomienda', COUNT(*) FROM public.encomienda
UNION ALL SELECT 'guia_envio', COUNT(*) FROM public.guia_envio
UNION ALL SELECT 'ruta', COUNT(*) FROM public.ruta
UNION ALL SELECT 'asignacion_ruta', COUNT(*) FROM public.asignacion_ruta
UNION ALL SELECT 'evento_rastreo', COUNT(*) FROM public.evento_rastreo
UNION ALL SELECT 'metodo_pago', COUNT(*) FROM public.metodo_pago
UNION ALL SELECT 'pago', COUNT(*) FROM public.pago
UNION ALL SELECT 'tipo_dte', COUNT(*) FROM public.tipo_dte
UNION ALL SELECT 'estado_dte', COUNT(*) FROM public.estado_dte
UNION ALL SELECT 'servicio_tarifa', COUNT(*) FROM public.servicio_tarifa
UNION ALL SELECT 'documento_dte', COUNT(*) FROM public.documento_dte
UNION ALL SELECT 'detalle_dte', COUNT(*) FROM public.detalle_dte
UNION ALL SELECT 'tipo_incidencia', COUNT(*) FROM public.tipo_incidencia
UNION ALL SELECT 'incidencia', COUNT(*) FROM public.incidencia
ORDER BY tabla;

-- Auditoria de conteos: los resultados esperados deben sumar 5,690.
WITH conteos AS (
    SELECT 'agencia' AS tabla, 1::BIGINT AS esperado, COUNT(*)::BIGINT AS real FROM public.agencia
    UNION ALL SELECT 'sucursal', 14, COUNT(*) FROM public.sucursal
    UNION ALL SELECT 'empleado', 56, COUNT(*) FROM public.empleado
    UNION ALL SELECT 'repartidor', 28, COUNT(*) FROM public.repartidor
    UNION ALL SELECT 'cliente', 300, COUNT(*) FROM public.cliente
    UNION ALL SELECT 'estado_encomienda', 8, COUNT(*) FROM public.estado_encomienda
    UNION ALL SELECT 'encomienda', 500, COUNT(*) FROM public.encomienda
    UNION ALL SELECT 'guia_envio', 500, COUNT(*) FROM public.guia_envio
    UNION ALL SELECT 'ruta', 50, COUNT(*) FROM public.ruta
    UNION ALL SELECT 'asignacion_ruta', 500, COUNT(*) FROM public.asignacion_ruta
    UNION ALL SELECT 'evento_rastreo', 2000, COUNT(*) FROM public.evento_rastreo
    UNION ALL SELECT 'metodo_pago', 5, COUNT(*) FROM public.metodo_pago
    UNION ALL SELECT 'pago', 400, COUNT(*) FROM public.pago
    UNION ALL SELECT 'tipo_dte', 5, COUNT(*) FROM public.tipo_dte
    UNION ALL SELECT 'estado_dte', 5, COUNT(*) FROM public.estado_dte
    UNION ALL SELECT 'servicio_tarifa', 10, COUNT(*) FROM public.servicio_tarifa
    UNION ALL SELECT 'documento_dte', 400, COUNT(*) FROM public.documento_dte
    UNION ALL SELECT 'detalle_dte', 800, COUNT(*) FROM public.detalle_dte
    UNION ALL SELECT 'tipo_incidencia', 8, COUNT(*) FROM public.tipo_incidencia
    UNION ALL SELECT 'incidencia', 100, COUNT(*) FROM public.incidencia
)
SELECT tabla, esperado, real, real - esperado AS diferencia,
       CASE WHEN real = esperado THEN 'OK' ELSE 'REVISAR' END AS resultado
FROM conteos
ORDER BY tabla;

-- Auditoria de relaciones principales.
SELECT
    (SELECT COUNT(*)
     FROM public.encomienda e
     LEFT JOIN public.guia_envio g ON g.id_encomienda = e.id_encomienda
     WHERE g.id_guia IS NULL) AS encomiendas_sin_guia,
    (SELECT COUNT(*)
     FROM (SELECT id_encomienda
           FROM public.guia_envio
           GROUP BY id_encomienda
           HAVING COUNT(*) > 1) q) AS grupos_guia_duplicada,
    (SELECT COUNT(*)
     FROM public.encomienda e
     LEFT JOIN public.asignacion_ruta ar ON ar.id_encomienda = e.id_encomienda
     WHERE ar.id_encomienda IS NULL) AS encomiendas_sin_asignacion,
    (SELECT COUNT(*)
     FROM public.asignacion_ruta ar
     JOIN public.repartidor r ON r.id_repartidor = ar.id_repartidor
     JOIN public.encomienda e ON e.id_encomienda = ar.id_encomienda
     WHERE r.id_sucursal <> e.id_sucursal_origen) AS asignaciones_fuera_de_sucursal,
    (SELECT COUNT(*)
     FROM (
         SELECT e.id_encomienda
         FROM public.encomienda e
         LEFT JOIN public.evento_rastreo ev ON ev.id_encomienda = e.id_encomienda
         GROUP BY e.id_encomienda
         HAVING COUNT(ev.id_encomienda) <> 4
     ) q) AS encomiendas_con_eventos_distintos_de_4;

-- Auditoria de pagos: calificar id_guia para evitar ambiguedad.
SELECT
    COUNT(*) AS total_pagos,
    COUNT(DISTINCT p.id_guia) AS guias_unicas_pagadas,
    COUNT(*) FILTER (WHERE p.estado_pago = 'Pagado') AS pagados,
    COUNT(*) FILTER (WHERE p.estado_pago = 'Pendiente') AS pendientes,
    COUNT(*) FILTER (WHERE p.estado_pago = 'Anulado') AS anulados,
    COUNT(*) FILTER (
        WHERE p.estado_pago NOT IN ('Pagado', 'Pendiente', 'Anulado')
    ) AS estados_pago_invalidos,
    COUNT(*) FILTER (WHERE p.monto <> g.tarifa) AS pagos_con_monto_distinto_de_tarifa
FROM public.pago p
JOIN public.guia_envio g ON g.id_guia = p.id_guia;

-- Auditoria DTE y detalles.
SELECT
    COUNT(*) AS documentos,
    COUNT(DISTINCT d.id_guia) AS guias_documentadas,
    COUNT(*) FILTER (WHERE d.id_cliente_receptor <> e.id_destinatario)
        AS receptores_distintos_del_destinatario,
    COUNT(*) FILTER (WHERE d.ambiente <> '00')
        AS documentos_fuera_de_ambiente_pruebas,
    COUNT(*) FILTER (
        WHERE d.total_pagar <> d.total_gravado + d.iva
    ) AS encabezados_con_total_inconsistente,
    COUNT(*) FILTER (WHERE d.sello_recepcion IS NOT NULL)
        AS documentos_con_sello_no_nulo
FROM public.documento_dte d
JOIN public.guia_envio g ON g.id_guia = d.id_guia
JOIN public.encomienda e ON e.id_encomienda = g.id_encomienda;

SELECT
    COUNT(*) FILTER (WHERE cantidad_detalles <> 2)
        AS documentos_con_detalles_distintos_de_2,
    COUNT(*) FILTER (WHERE total_gravado <> suma_gravada)
        AS documentos_con_venta_gravada_distinta,
    COUNT(*) FILTER (WHERE iva <> suma_iva)
        AS documentos_con_iva_distinto,
    COUNT(*) FILTER (WHERE total_pagar <> suma_gravada + suma_iva)
        AS documentos_con_total_detalle_distinto
FROM (
    SELECT
        d.id_documento,
        d.total_gravado,
        d.iva,
        d.total_pagar,
        COUNT(dt.id_detalle) AS cantidad_detalles,
        COALESCE(SUM(dt.venta_gravada), 0) AS suma_gravada,
        COALESCE(SUM(dt.iva_item), 0) AS suma_iva
    FROM public.documento_dte d
    LEFT JOIN public.detalle_dte dt ON dt.id_documento = d.id_documento
    GROUP BY d.id_documento, d.total_gravado, d.iva, d.total_pagar
) q;

-- Auditoria de incidencias.
SELECT
    COUNT(*) AS total_incidencias,
    COUNT(*) FILTER (
        WHERE prioridad NOT IN ('Baja', 'Media', 'Alta', 'Critica')
    ) AS prioridades_invalidas,
    COUNT(*) FILTER (
        WHERE estado NOT IN ('Abierta', 'En proceso', 'Resuelta')
    ) AS estados_invalidos,
    COUNT(*) FILTER (
        WHERE fecha_resolucion IS NOT NULL
          AND fecha_resolucion < fecha_reporte
    ) AS resoluciones_anteriores_al_reporte
FROM public.incidencia;

-- Restricciones CHECK y FK: la columna real se usa en ORDER BY.
SELECT
    conrelid::regclass AS tabla,
    conname AS restriccion,
    contype AS tipo,
    convalidated AS validada,
    pg_get_constraintdef(oid) AS definicion
FROM pg_constraint
WHERE connamespace = 'public'::regnamespace
  AND contype IN ('c', 'f')
ORDER BY conrelid::regclass::TEXT, contype, conname;

-- Fin de carga y auditoria. Las consultas anteriores son de solo lectura.
