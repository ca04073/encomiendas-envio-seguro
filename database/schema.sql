-- =====================================================================
-- Proyecto: Encomiendas "Envío Seguro"
-- Script de creación de tablas (PostgreSQL)
-- =====================================================================
-- PASO 1 (ejecutar conectado a la base "postgres", fuera de este script):
--     CREATE DATABASE envio_seguro ENCODING 'UTF8';
-- PASO 2: conectarse a la base envio_seguro (en pgAdmin: clic derecho
--         sobre la base > Query Tool) y ejecutar este script completo.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Limpieza (permite volver a ejecutar el script desde cero)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS incidencia        CASCADE;
DROP TABLE IF EXISTS detalle_dte       CASCADE;
DROP TABLE IF EXISTS documento_dte     CASCADE;
DROP TABLE IF EXISTS pago              CASCADE;
DROP TABLE IF EXISTS evento_rastreo    CASCADE;
DROP TABLE IF EXISTS asignacion_ruta   CASCADE;
DROP TABLE IF EXISTS ruta              CASCADE;
DROP TABLE IF EXISTS guia_envio        CASCADE;
DROP TABLE IF EXISTS encomienda        CASCADE;
DROP TABLE IF EXISTS tipo_incidencia   CASCADE;
DROP TABLE IF EXISTS servicio_tarifa   CASCADE;
DROP TABLE IF EXISTS estado_dte        CASCADE;
DROP TABLE IF EXISTS tipo_dte          CASCADE;
DROP TABLE IF EXISTS metodo_pago       CASCADE;
DROP TABLE IF EXISTS estado_encomienda CASCADE;
DROP TABLE IF EXISTS cliente           CASCADE;
DROP TABLE IF EXISTS repartidor        CASCADE;
DROP TABLE IF EXISTS empleado          CASCADE;
DROP TABLE IF EXISTS sucursal          CASCADE;
DROP TABLE IF EXISTS agencia           CASCADE;

-- =====================================================================
-- BLOQUE 1: Estructura de la empresa
-- =====================================================================

CREATE TABLE agencia (
    id_agencia          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre              VARCHAR(100) NOT NULL,
    nit                 VARCHAR(17)  NOT NULL UNIQUE,
    nrc                 VARCHAR(10)  UNIQUE,
    actividad_economica VARCHAR(150),
    telefono            VARCHAR(15),
    correo              VARCHAR(100),
    fecha_creacion      DATE NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE sucursal (
    id_sucursal            INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_agencia             INT NOT NULL,
    codigo_establecimiento VARCHAR(4)   NOT NULL UNIQUE,
    nombre                 VARCHAR(100) NOT NULL,
    direccion              VARCHAR(200) NOT NULL,
    municipio              VARCHAR(80)  NOT NULL,
    departamento           VARCHAR(50)  NOT NULL,
    telefono               VARCHAR(15),
    activa                 BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_sucursal_agencia
        FOREIGN KEY (id_agencia) REFERENCES agencia (id_agencia)
);

CREATE TABLE empleado (
    id_empleado        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_sucursal        INT NOT NULL,
    nombres            VARCHAR(80) NOT NULL,
    apellidos          VARCHAR(80) NOT NULL,
    dui                VARCHAR(10) NOT NULL UNIQUE,
    cargo              VARCHAR(50) NOT NULL,
    telefono           VARCHAR(15),
    correo             VARCHAR(100) UNIQUE,
    fecha_contratacion DATE NOT NULL,
    activo             BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_empleado_sucursal
        FOREIGN KEY (id_sucursal) REFERENCES sucursal (id_sucursal)
);

CREATE TABLE repartidor (
    id_repartidor   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_sucursal     INT NOT NULL,
    nombres         VARCHAR(80) NOT NULL,
    apellidos       VARCHAR(80) NOT NULL,
    dui             VARCHAR(10) NOT NULL UNIQUE,
    numero_licencia VARCHAR(20) NOT NULL UNIQUE,
    tipo_vehiculo   VARCHAR(30) NOT NULL,
    placa           VARCHAR(10) UNIQUE,
    telefono        VARCHAR(15),
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_repartidor_sucursal
        FOREIGN KEY (id_sucursal) REFERENCES sucursal (id_sucursal)
);

-- =====================================================================
-- BLOQUE 2: Clientes y envíos
-- =====================================================================

CREATE TABLE cliente (
    id_cliente         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tipo_contribuyente VARCHAR(20) NOT NULL,
    nombres            VARCHAR(100) NOT NULL,
    apellidos          VARCHAR(100),
    dui                VARCHAR(10) UNIQUE,
    nit                VARCHAR(17) UNIQUE,
    nrc                VARCHAR(10),
    giro               VARCHAR(150),
    telefono           VARCHAR(15),
    correo             VARCHAR(100),
    direccion          VARCHAR(200),
    municipio          VARCHAR(80),
    departamento       VARCHAR(50),
    CONSTRAINT ck_cliente_tipo_contribuyente
        CHECK (tipo_contribuyente IN ('Consumidor final', 'Contribuyente'))
);

CREATE TABLE estado_encomienda (
    id_estado   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      VARCHAR(40) NOT NULL UNIQUE,
    descripcion VARCHAR(150)
);

CREATE TABLE encomienda (
    id_encomienda       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_remitente        INT NOT NULL,
    id_destinatario     INT NOT NULL,
    id_sucursal_origen  INT NOT NULL,
    id_sucursal_destino INT NOT NULL,
    id_estado           INT NOT NULL,
    descripcion         VARCHAR(200) NOT NULL,
    peso_kg             NUMERIC(8,2) NOT NULL,
    valor_declarado     NUMERIC(10,2) NOT NULL DEFAULT 0,
    fecha_recepcion     TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_encomienda_remitente
        FOREIGN KEY (id_remitente) REFERENCES cliente (id_cliente),
    CONSTRAINT fk_encomienda_destinatario
        FOREIGN KEY (id_destinatario) REFERENCES cliente (id_cliente),
    CONSTRAINT fk_encomienda_sucursal_origen
        FOREIGN KEY (id_sucursal_origen) REFERENCES sucursal (id_sucursal),
    CONSTRAINT fk_encomienda_sucursal_destino
        FOREIGN KEY (id_sucursal_destino) REFERENCES sucursal (id_sucursal),
    CONSTRAINT fk_encomienda_estado
        FOREIGN KEY (id_estado) REFERENCES estado_encomienda (id_estado),
    CONSTRAINT ck_encomienda_peso CHECK (peso_kg > 0),
    CONSTRAINT ck_encomienda_valor CHECK (valor_declarado >= 0),
    CONSTRAINT ck_encomienda_sucursales
        CHECK (id_sucursal_origen <> id_sucursal_destino)
);

-- Relación 1:1 con Encomienda (UNIQUE sobre id_encomienda)
CREATE TABLE guia_envio (
    id_guia       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_encomienda INT NOT NULL UNIQUE,
    id_empleado   INT NOT NULL,
    numero_guia   VARCHAR(20) NOT NULL UNIQUE,
    fecha_emision TIMESTAMP NOT NULL DEFAULT NOW(),
    tipo_cobro    VARCHAR(20) NOT NULL,
    tarifa        NUMERIC(10,2) NOT NULL,
    CONSTRAINT fk_guia_encomienda
        FOREIGN KEY (id_encomienda) REFERENCES encomienda (id_encomienda),
    CONSTRAINT fk_guia_empleado
        FOREIGN KEY (id_empleado) REFERENCES empleado (id_empleado),
    CONSTRAINT ck_guia_tipo_cobro
        CHECK (tipo_cobro IN ('Remitente', 'Contra entrega')),
    CONSTRAINT ck_guia_tarifa CHECK (tarifa >= 0)
);

-- =====================================================================
-- BLOQUE 3: Logística y trazabilidad
-- =====================================================================

CREATE TABLE ruta (
    id_ruta             INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_sucursal_origen  INT NOT NULL,
    id_sucursal_destino INT NOT NULL,
    nombre              VARCHAR(100) NOT NULL,
    distancia_km        NUMERIC(7,2),
    tiempo_estimado_min INT,
    CONSTRAINT fk_ruta_sucursal_origen
        FOREIGN KEY (id_sucursal_origen) REFERENCES sucursal (id_sucursal),
    CONSTRAINT fk_ruta_sucursal_destino
        FOREIGN KEY (id_sucursal_destino) REFERENCES sucursal (id_sucursal),
    CONSTRAINT ck_ruta_distancia CHECK (distancia_km > 0),
    CONSTRAINT ck_ruta_tiempo CHECK (tiempo_estimado_min > 0),
    CONSTRAINT ck_ruta_sucursales
        CHECK (id_sucursal_origen <> id_sucursal_destino)
);

CREATE TABLE asignacion_ruta (
    id_asignacion INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_ruta       INT NOT NULL,
    id_repartidor INT NOT NULL,
    id_encomienda INT NOT NULL,
    fecha_salida  TIMESTAMP NOT NULL,
    fecha_llegada TIMESTAMP,
    observaciones VARCHAR(200),
    CONSTRAINT fk_asignacion_ruta
        FOREIGN KEY (id_ruta) REFERENCES ruta (id_ruta),
    CONSTRAINT fk_asignacion_repartidor
        FOREIGN KEY (id_repartidor) REFERENCES repartidor (id_repartidor),
    CONSTRAINT fk_asignacion_encomienda
        FOREIGN KEY (id_encomienda) REFERENCES encomienda (id_encomienda),
    CONSTRAINT ck_asignacion_fechas
        CHECK (fecha_llegada IS NULL OR fecha_llegada >= fecha_salida)
);

CREATE TABLE evento_rastreo (
    id_evento     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_encomienda INT NOT NULL,
    id_estado     INT NOT NULL,
    id_sucursal   INT NOT NULL,
    id_empleado   INT,
    fecha_hora    TIMESTAMP NOT NULL DEFAULT NOW(),
    observacion   VARCHAR(200),
    CONSTRAINT fk_evento_encomienda
        FOREIGN KEY (id_encomienda) REFERENCES encomienda (id_encomienda),
    CONSTRAINT fk_evento_estado
        FOREIGN KEY (id_estado) REFERENCES estado_encomienda (id_estado),
    CONSTRAINT fk_evento_sucursal
        FOREIGN KEY (id_sucursal) REFERENCES sucursal (id_sucursal),
    CONSTRAINT fk_evento_empleado
        FOREIGN KEY (id_empleado) REFERENCES empleado (id_empleado)
);

-- =====================================================================
-- BLOQUE 4: Cobros
-- =====================================================================

CREATE TABLE metodo_pago (
    id_metodo_pago INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre         VARCHAR(40) NOT NULL UNIQUE,
    descripcion    VARCHAR(100)
);

CREATE TABLE pago (
    id_pago            INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_guia            INT NOT NULL,
    id_cliente_pagador INT NOT NULL,
    id_metodo_pago     INT NOT NULL,
    id_empleado        INT NOT NULL,
    monto              NUMERIC(10,2) NOT NULL,
    fecha_pago         TIMESTAMP NOT NULL DEFAULT NOW(),
    estado_pago        VARCHAR(20) NOT NULL,
    referencia         VARCHAR(50),
    CONSTRAINT fk_pago_guia
        FOREIGN KEY (id_guia) REFERENCES guia_envio (id_guia),
    CONSTRAINT fk_pago_cliente
        FOREIGN KEY (id_cliente_pagador) REFERENCES cliente (id_cliente),
    CONSTRAINT fk_pago_metodo
        FOREIGN KEY (id_metodo_pago) REFERENCES metodo_pago (id_metodo_pago),
    CONSTRAINT fk_pago_empleado
        FOREIGN KEY (id_empleado) REFERENCES empleado (id_empleado),
    CONSTRAINT ck_pago_monto CHECK (monto > 0),
    CONSTRAINT ck_pago_estado
        CHECK (estado_pago IN ('Pendiente', 'Pagado', 'Anulado'))
);

-- =====================================================================
-- BLOQUE 5: Facturación electrónica (DTE)
-- =====================================================================

CREATE TABLE tipo_dte (
    id_tipo_dte INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo      VARCHAR(2)  NOT NULL UNIQUE,
    nombre      VARCHAR(80) NOT NULL
);

CREATE TABLE estado_dte (
    id_estado_dte INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre        VARCHAR(40) NOT NULL UNIQUE,
    descripcion   VARCHAR(150)
);

CREATE TABLE servicio_tarifa (
    id_servicio INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      VARCHAR(80) NOT NULL UNIQUE,
    descripcion VARCHAR(150),
    precio_base NUMERIC(10,2) NOT NULL,
    aplica_iva  BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT ck_servicio_precio CHECK (precio_base >= 0)
);

CREATE TABLE documento_dte (
    id_documento        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_guia             INT NOT NULL,
    id_tipo_dte         INT NOT NULL,
    id_estado_dte       INT NOT NULL,
    id_cliente_receptor INT NOT NULL,
    codigo_generacion   UUID NOT NULL UNIQUE,
    numero_control      VARCHAR(31) NOT NULL UNIQUE,
    fecha_emision       DATE NOT NULL,
    hora_emision        TIME NOT NULL,
    ambiente            CHAR(2) NOT NULL,
    total_gravado       NUMERIC(10,2) NOT NULL,
    iva                 NUMERIC(10,2) NOT NULL,
    total_pagar         NUMERIC(10,2) NOT NULL,
    sello_recepcion     VARCHAR(40),
    CONSTRAINT fk_dte_guia
        FOREIGN KEY (id_guia) REFERENCES guia_envio (id_guia),
    CONSTRAINT fk_dte_tipo
        FOREIGN KEY (id_tipo_dte) REFERENCES tipo_dte (id_tipo_dte),
    CONSTRAINT fk_dte_estado
        FOREIGN KEY (id_estado_dte) REFERENCES estado_dte (id_estado_dte),
    CONSTRAINT fk_dte_cliente
        FOREIGN KEY (id_cliente_receptor) REFERENCES cliente (id_cliente),
    CONSTRAINT ck_dte_ambiente CHECK (ambiente IN ('00', '01')),
    CONSTRAINT ck_dte_totales
        CHECK (total_gravado >= 0 AND iva >= 0 AND total_pagar >= 0)
);

CREATE TABLE detalle_dte (
    id_detalle      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_documento    INT NOT NULL,
    id_servicio     INT NOT NULL,
    descripcion     VARCHAR(150) NOT NULL,
    cantidad        NUMERIC(8,2) NOT NULL,
    precio_unitario NUMERIC(10,2) NOT NULL,
    descuento       NUMERIC(10,2) NOT NULL DEFAULT 0,
    venta_gravada   NUMERIC(10,2) NOT NULL,
    iva_item        NUMERIC(10,2) NOT NULL,
    CONSTRAINT fk_detalle_documento
        FOREIGN KEY (id_documento) REFERENCES documento_dte (id_documento),
    CONSTRAINT fk_detalle_servicio
        FOREIGN KEY (id_servicio) REFERENCES servicio_tarifa (id_servicio),
    CONSTRAINT ck_detalle_cantidad CHECK (cantidad > 0)
);

-- =====================================================================
-- BLOQUE 6: Incidencias
-- =====================================================================

CREATE TABLE tipo_incidencia (
    id_tipo_incidencia INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre             VARCHAR(50) NOT NULL UNIQUE,
    descripcion        VARCHAR(150)
);

CREATE TABLE incidencia (
    id_incidencia        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_encomienda        INT NOT NULL,
    id_tipo_incidencia   INT NOT NULL,
    id_empleado_reporta  INT NOT NULL,
    id_empleado_resuelve INT,
    descripcion          VARCHAR(300) NOT NULL,
    fecha_reporte        TIMESTAMP NOT NULL DEFAULT NOW(),
    fecha_resolucion     TIMESTAMP,
    estado               VARCHAR(20) NOT NULL,
    prioridad            VARCHAR(10) NOT NULL,
    CONSTRAINT fk_incidencia_encomienda
        FOREIGN KEY (id_encomienda) REFERENCES encomienda (id_encomienda),
    CONSTRAINT fk_incidencia_tipo
        FOREIGN KEY (id_tipo_incidencia) REFERENCES tipo_incidencia (id_tipo_incidencia),
    CONSTRAINT fk_incidencia_reporta
        FOREIGN KEY (id_empleado_reporta) REFERENCES empleado (id_empleado),
    CONSTRAINT fk_incidencia_resuelve
        FOREIGN KEY (id_empleado_resuelve) REFERENCES empleado (id_empleado),
    CONSTRAINT ck_incidencia_estado
        CHECK (estado IN ('Abierta', 'En proceso', 'Resuelta', 'Cerrada')),
    CONSTRAINT ck_incidencia_prioridad
        CHECK (prioridad IN ('Baja', 'Media', 'Alta', 'Crítica')),
    CONSTRAINT ck_incidencia_fechas
        CHECK (fecha_resolucion IS NULL OR fecha_resolucion >= fecha_reporte)
);

-- =====================================================================
-- ÍNDICES sobre claves foráneas de consulta frecuente
-- =====================================================================
CREATE INDEX idx_sucursal_agencia      ON sucursal (id_agencia);
CREATE INDEX idx_empleado_sucursal     ON empleado (id_sucursal);
CREATE INDEX idx_encomienda_remitente  ON encomienda (id_remitente);
CREATE INDEX idx_encomienda_destinat   ON encomienda (id_destinatario);
CREATE INDEX idx_encomienda_estado     ON encomienda (id_estado);
CREATE INDEX idx_evento_encomienda     ON evento_rastreo (id_encomienda, fecha_hora);
CREATE INDEX idx_pago_guia             ON pago (id_guia);
CREATE INDEX idx_dte_guia              ON documento_dte (id_guia);
CREATE INDEX idx_detalle_documento     ON detalle_dte (id_documento);
CREATE INDEX idx_incidencia_encomienda ON incidencia (id_encomienda);

-- =====================================================================
-- Verificación: debe devolver 20 tablas
-- =====================================================================
SELECT COUNT(*) AS total_tablas
FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE';
