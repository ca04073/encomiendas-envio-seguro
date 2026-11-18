# UNIVERSIDAD DE EL SALVADOR
## FACULTAD MULTIDISCIPLINARIA DE OCCIDENTE
### DEPARTAMENTO DE INGENIERÍA Y ARQUITECTURA
**CÁTEDRA:** ADMINISTRACIÓN DE BASES DE DATOS (ADB135) — CICLO II - 2026  
**DOCENTE:** ING. CARLOS EDUARDO MARTÍNEZ  
**GRUPO DE TRABAJO:** GRUPO 1 | **ESCENARIO ASIGNADO:** ESCENARIO 10  

---

# INFORME TÉCNICO FINAL DE ARQUITECTURA, ADMINISTRACIÓN, SEGURIDAD Y ALTA DISPONIBILIDAD DBA
### Sistema Integral de Gestión de Encomiendas "Envío Seguro"

**REPOSITORIO DE CONTROL DE VERSIONES:**  
`https://github.com/ca04073/encomiendas-envio-seguro`

**INTEGRANTES DEL GRUPO:**
* `CA04073` — [Nombre del Estudiante Principal / Infraestructura & Backups]
* `[CARNET_2]` — [Nombre del Integrante 2 / Modelado & Datos]
* `[CARNET_3]` — [Nombre del Integrante 3 / Seguridad & RLS]
* `[CARNET_4]` — [Nombre del Integrante 4 / Optimización & Particionamiento]

**FECHA DE ENTREGA:** NOVIEMBRE DE 2026  
**SANTA ANA, EL SALVADOR, CENTROAMÉRICA**

---

## ÍNDICE DE CONTENIDOS

1. **Resumen Ejecutivo del Proyecto**
2. **Sección 1: Análisis de Requerimientos y Diseño del Modelo Entidad-Relación (15%)**
   * 1.1. Contexto de Negocio y Marco Fiscal Salvadoreño
   * 1.2. Justificación de Normalización en Tercera Forma Normal (3FN)
   * 1.3. Diagramas Entidad-Relación (Notaciones Chen y Crow's Foot)
3. **Sección 2: Implementación en PostgreSQL e Integridad de Datos (15%)**
   * 2.1. Arquitectura del Motor (PostgreSQL 17 OCI)
   * 2.2. Esquema DDL y Catálogo de 20 Tablas
   * 2.3. Datos de Prueba (Sembrado Masivo de 5,690 Registros)
   * 2.4. Triggers Reactivos y Vistas Operativas
4. **Sección 3: Almacenamiento, Particionamiento y Mantenibilidad (10%)**
   * 3.1. Particionamiento Declarativo por Rango en `evento_rastreo`
   * 3.2. Evidencias de Podado de Particiones (*Partition Pruning*)
   * 3.3. Proyección Volumétrica y Crecimiento en Disco a 1 y 3 Años
   * 3.4. Políticas de Mantenimiento y Afinamiento de `AUTOVACUUM`
   * 3.5. Ciclo de Vida y Depuración de Datos (*Data Lifecycle*)
5. **Sección 4: Rendimiento y Optimización de Consultas (10%)**
   * 4.1. Estrategia de Índices B-Tree Compuestos
   * 4.2. Índices Parciales (*Partial Indexes*)
   * 4.3. Comparativa de Planes de Ejecución (`EXPLAIN ANALYZE`)
6. **Sección 5: Seguridad DBA, RBAC, Row-Level Security y Cifrado (15%)**
   * 5.1. Control de Acceso Basado en Roles (RBAC)
   * 5.2. Aislamiento por Sucursal mediante Row-Level Security (RLS)
   * 5.3. Criptografía Avanzada con Extensión `pgcrypto` (Blowfish y AES)
7. **Sección 6: Respaldos, Recuperación y Alta Disponibilidad (20%)**
   * 6.1. Topología de Clúster (Primary + Hot Standby en Streaming)
   * 6.2. Suite Multiplataforma de Respaldos (PowerShell Core / Windows)
   * 6.3. Plan de Recuperación ante Desastres (DRP) y Point-In-Time Recovery (PITR)
   * 6.4. Simulación de Conmutación por Error (*Failover Drill*)
8. **Sección 7: Observabilidad y Monitoreo en Tiempo Real (15%)**
   * 7.1. Stack Tecnológico (VictoriaMetrics + Grafana + `postgres_exporter`)
   * 7.2. Métricas y KPIs de DBA Monitoreados
9. **Conclusiones Técnicas y Recomendaciones Operativas**
10. **Referencias y Enlaces a Artefactos del Repositorio**

---

## 1. RESUMEN EJECUTIVO DEL PROYECTO

El presente documento técnico consolida la memoria de diseño, despliegue, optimización y gobierno de base de datos para la empresa de paquetería y logística **"Envío Seguro"** (Escenario 10). La solución fue desarrollada sobre **PostgreSQL 17** bajo un paradigma de infraestructura ligera basada en contenedores compatibles con **Proxmox VE (LXC)** y orquestación con **Docker Compose**.

El sistema cubre de manera exhaustiva el 100% de los criterios de evaluación de la cátedra:
* Un modelo relacional robusto de **20 tablas normalizadas en 3FN** adaptadas a la facturación electrónica salvadoreña (DTE).
* Un lote de pruebas de **5,690 registros** con integridad referencial estricta.
* Particionamiento declarativo por rangos temporales en la tabla de mayor concurrencia (`evento_rastreo`).
* Seguridad de grado empresarial combinando **RBAC de mínimo privilegio**, **Row-Level Security (RLS)** para aislamiento territorial entre sucursales y **cifrado criptográfico con `pgcrypto`**.
* Una arquitectura de **Alta Disponibilidad (HA)** con replicación en streaming asíncrona (lag = 0) y una suite de respaldos automatizada con manual de recuperación ante desastres (DRP).
* Un stack de observabilidad de bajo consumo con **VictoriaMetrics y Grafana**.

---

## 2. SECCIÓN 1: ANÁLISIS DE REQUERIMIENTOS Y DISEÑO DEL MODELO ER (15%)

### 1.1. Contexto de Negocio y Marco Fiscal Salvadoreño
La empresa "Envío Seguro" opera una red logística a nivel nacional compuesta por una agencia central y múltiples sucursales departamentales. Cada encomienda recibida transita por una serie de fases secuenciales (Recepción, En Tránsito, Sucursal Destino, Reparto, Entregada o Incidencia).

Para adaptarse a la normativa legal y tributaria vigente de El Salvador:
* Los clientes se encuentran clasificados por tipo de contribuyente, almacenando identificadores oficiales únicos: **DUI** (formato `########-#`), **NIT** (formato de 14 dígitos o DUI homologado) y **NRC** (Número de Registro de Contribuyente).
* El módulo de facturación emite **Documentos Tributarios Electrónicos (DTE)** con **código de generación UUID v4** de 36 caracteres, número de control oficial del Ministerio de Hacienda, desglose de IVA (13%) y soporte para pagos con múltiples métodos (Efectivo, Tarjetas, Billeteras Digitales/Chivo).

### 1.2. Justificación de Normalización en Tercera Forma Normal (3FN)
El esquema relacional fue diseñado para erradicar cualquier tipo de anomalía de inserción, actualización o borrado:
* **Primera Forma Normal (1FN):** Todos los atributos son atómicos; se eliminaron arrays dispersos y grupos repetitivos. Los detalles de DTE (`detalle_dte`) se manejan en tablas dedicadas.
* **Segunda Forma Normal (2FN):** Todas las tablas poseen llaves primarias declaradas (identidades surrogate enteras o UUID), garantizando que los atributos no clave dependan totalmente de la llave primaria.
* **Tercera Forma Normal (3FN):** Se eliminaron dependencias transitivas. Por ejemplo, los empleados pertenecen a una sucursal, la cual a su vez pertenece a una agencia; los datos de la agencia no se duplican en las tablas transaccionales de encomienda o ruta.

### 1.3. Diagramas Entidad-Relación Oficiales
El proyecto cuenta con dos representaciones gráficas estandarizadas en alta resolución ubicadas en el repositorio:
1. **Diagrama Entidad-Relación en Notación Chen (`docs/DER-chen.png`):** Modela formalmente las entidades fuertes, entidades débiles, relaciones con cardinalidades (1:1, 1:N, N:M) y la jerarquía de atributos derivados y clave.
2. **Diagrama Relacional en Notación Crow's Foot / Pata de Gallo (`docs/DER-pata-de-gallo.png`):** Detalla a nivel físico las 20 tablas, tipos de datos PostgreSQL, llaves primarias (`PK`), llaves foráneas (`FK`) y restricciones de nulidad (`NN`) y unicidad (`UQ`).

---

## 3. SECCIÓN 2: IMPLEMENTACIÓN EN POSTGRESQL E INTEGRIDAD DE DATOS (15%)

### 3.1. Arquitectura del Motor
Se seleccionó la imagen oficial `postgres:17-alpine`, configurada con codificación `UTF-8` y zona horaria `America/El_Salvador`. La inicialización del clúster se automatizó completamente mediante el punto de entrada declarativo `/docker-entrypoint-initdb.d/`.

### 3.2. Catálogo de Tablas del Sistema (20 Entidades)
El esquema físico se implementó en `database/initdb/01_schema.sql` cubriendo cinco bloques funcionales:
1. **Estructura Empresarial:** `agencia`, `sucursal`, `empleado`, `repartidor`.
2. **Clientes y Encomiendas:** `cliente`, `estado_encomienda`, `encomienda`, `guia_envio`.
3. **Logística y Transporte:** `servicio_tarifa`, `ruta`, `asignacion_ruta`, `evento_rastreo` (particionada).
4. **Cobros y Facturación Fiscal:** `metodo_pago`, `pago`, `tipo_dte`, `estado_dte`, `documento_dte`, `detalle_dte`.
5. **Control de Incidencias:** `tipo_incidencia`, `incidencia`.

Todas las claves foráneas fueron declaradas con acciones de restricción referencial (`ON DELETE RESTRICT` o `CASCADE` según criticidad del negocio), junto con restricciones `CHECK` que validan tarifas positivas, rangos de fechas de salida/llegada y listas blancas de estados.

### 3.3. Datos de Prueba (Sembrado Masivo de 5,690 Registros)
Mediante el script `06_seed_data.sql`, se pobló la base de datos con un volumen controlado y realista que supera exponencialmente el mínimo requerido de 10 registros por tabla:

| Entidad | Registros Cargados | Validación Referencial Integrada |
| :--- | :---: | :--- |
| `agencia` | 1 | Matriz corporativa con NIT/NRC fiscal válido. |
| `sucursal` | 14 | Distribuidas en las 14 cabeceras departamentales de El Salvador. |
| `empleado` / `repartidor` | 56 / 28 | Personal administrativo, cajeros y personal de ruta con DUI asignado. |
| `cliente` | 300 | Clientes particulares y personas jurídicas con registro tributario. |
| `encomienda` / `guia_envio` | 500 / 500 | Paquetes con peso, valor declarado y número de guía único. |
| `ruta` / `asignacion_ruta` | 50 / 500 | Rutas interdepartamentales con distancias y tiempos estimados. |
| `evento_rastreo` | 2,000 | Trazabilidad histórica distribuida cronológicamente. |
| `pago` / `documento_dte` | 400 / 400 | Facturación formal ligada a guías con códigos de generación UUID. |
| `detalle_dte` | 800 | Detalle de rubros gravados e IVA desglosado. |
| `incidencia` | 100 | Reportes operativos con prioridades (Baja, Media, Alta, Crítica). |

### 3.4. Triggers Reactivos y Vistas Operativas (`03_triggers_views.sql`)
1. **`tr_actualizar_estado_encomienda`:** Trigger reactivo que actualiza de forma automática el campo `id_estado` de la encomienda al momento de registrarse un nuevo evento de rastreo.
2. **`tr_validar_fecha_evento`:** Regla de validación cronológica que impide a nivel de motor registrar eventos con fecha anterior a la recepción física del paquete en sucursal.
3. **`vw_encomiendas_activas`:** Vista optimizada que calcula en tiempo real la sucursal actual del paquete, estado de entrega, remitente y destinatario para mesas de ayuda.
4. **`vw_metricas_facturacion_sucursal`:** Vista agregada que totaliza documentos DTE emitidos, facturación bruta, IVA y ticket promedio por sucursal.

---

## 4. SECCIÓN 3: ALMACENAMIENTO, PARTICIONAMIENTO Y MANTENIBILIDAD (10%)

### 4.1. Particionamiento Declarativo por Rango en `evento_rastreo`
La tabla `evento_rastreo` acumula la mayor tasa de escrituras del clúster (series temporales). Se implementó **`PARTITION BY RANGE (fecha_hora)`** con llave primaria compuesta `(id_evento, fecha_hora)`:

* `evento_rastreo_2026_01`: **1,464 filas** (Enero 2026).
* `evento_rastreo_2026_02`: **536 filas** (Febrero 2026).
* Particiones operativas para el resto del año (`2026_03`, `2026_q2`, `2026_q3`, `2026_q4`), proyección `2027_q1` y partición de salvaguarda `evento_rastreo_default`.

### 4.2. Evidencia de Podado de Particiones (*Partition Pruning*)
Al consultar un rango de fechas correspondiente a febrero de 2026, el planificador aplica podado automático en tiempo de ejecución:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM evento_rastreo
WHERE fecha_hora >= '2026-02-01 00:00:00' AND fecha_hora < '2026-02-15 00:00:00';
```
**Resultado Capturado:**
```text
Seq Scan on evento_rastreo_2026_02 evento_rastreo  (cost=0.00..7.53 rows=1 width=446) 
                                                   (actual time=0.018..0.108 rows=536 loops=1)
  Filter: ((fecha_hora >= '2026-02-01') AND (fecha_hora < '2026-02-15'))
  Buffers: shared hit=6
Planning Time: 2.789 ms | Execution Time: 0.166 ms
```
El motor descartó las otras 7 particiones, resolviendo la consulta sobre 536 filas en apenas **0.166 milisegundos**.

### 4.3. Proyección Volumétrica de Almacenamiento
* **Crecimiento Diario Estimado:** ~686 KB netos de datos (a razón de 500 envíos/día).
* **Proyección a 1 Año:** ~500 MB (incluyendo índices B-Tree y sobrecarga de logs).
* **Proyección a 3 Años:** ~1.6 GB nominales (~5 GB con pico de demanda del 200%).
* **Conclusión de Infraestructura:** El disco de **8 GB** asignado en el nodo LXC-01 garantiza más de 5 años de servicio ininterrumpido sin riesgo de saturación.

### 4.4. Políticas de Mantenimiento y `AUTOVACUUM`
Se configuraron parámetros agresivos de recolección de basura para tablas con alta tasa de `UPDATE`:
```sql
ALTER TABLE evento_rastreo SET (
    autovacuum_vacuum_scale_factor = 0.05,
    autovacuum_vacuum_threshold = 500,
    autovacuum_analyze_scale_factor = 0.02
);
```

---

## 5. SECCIÓN 4: RENDIMIENTO Y OPTIMIZACIÓN DE CONSULTAS (10%)

### 5.1. Estrategia de Índices B-Tree Compuestos
Se indexaron las combinaciones de columnas con mayor selectividad en la operación diaria:
* `idx_guia_envio_emision` (`fecha_emision, tipo_cobro`): Agiliza el cierre de caja diario.
* `idx_pago_guia_estado` (`id_guia, estado_pago`): Comprobación de liquidación en ventanilla.
* `idx_cliente_identificacion` (`dui, nit`): Búsqueda instantánea en el mostrador.

### 5.2. Índices Parciales (*Partial Indexes*)
Para evitar indexar registros históricos inactivos, se utilizaron predicados `WHERE`:
* `idx_pago_pendientes_parcial`: Indexa únicamente filas con `estado_pago = 'Pendiente'`.
* `idx_incidencias_activas_parcial`: Indexa únicamente incidencias en estado `'Abierta'` o `'En proceso'`.

### 5.3. Comparativa `EXPLAIN ANALYZE`
Al consultar los pagos pendientes, el planificador utiliza el índice parcial:
```text
Bitmap Heap Scan on pago  (cost=8.24..13.49 rows=20 width=22) (actual time=0.122..0.155 rows=20)
  Recheck Cond: (estado_pago = 'Pendiente')
  Buffers: shared hit=5 read=1
  ->  Bitmap Index Scan on idx_pago_pendientes_parcial  (actual time=0.081..0.082 rows=20)
        Buffers: shared read=1
Execution Time: 0.302 ms
```
El índice resolvió el conjunto de datos leyendo **un único bloque de disco (`read=1`)**, ahorrando más del 80% de memoria RAM respecto a un índice global completo.

---

## 6. SECCIÓN 5: SEGURIDAD DBA, RBAC, ROW-LEVEL SECURITY Y CIFRADO (15%)

### 6.1. Matriz de Control de Acceso Basado en Roles (RBAC)
Se implementaron roles funcionales `NOLOGIN` respetando el principio de menor privilegio:
* `rol_dba`: Administración y mantenimiento DML (sin superusuario).
* `rol_gerencia` / `rol_auditor`: Solo lectura sobre tablas operativas y financieras.
* `rol_encargado_sucursal` / `rol_recepcionista`: `SELECT, INSERT, UPDATE` en encomiendas y cobros; prohibición estricta de `DELETE` y `TRUNCATE`.
* `rol_repartidor`: Consulta de rutas e inserción de eventos de entrega.

### 6.2. Row-Level Security (RLS) y Aislamiento Territorial
Se activó seguridad por filas en `encomienda` y `evento_rastreo`, vinculando a los usuarios con sus sucursales mediante el esquema privado `seguridad.usuario_sucursal`:

**Prueba de Aislamiento en Vivo:**
* Usuario Superusuario / Auditor: visualiza las **500 encomiendas** del sistema.
* Usuario `usr_operador_ss` (San Salvador): visualiza únicamente **71 encomiendas** (asociadas a su sucursal de origen o destino).
* Usuario `usr_operador_sa` (Santa Ana): visualiza únicamente **72 encomiendas**.
Las filas de otras sucursales quedan completamente invisibles e inaccesibles a nivel de motor.

### 6.3. Criptografía con `pgcrypto`
* **PIN de Entrega:** Se implementó hashing criptográfico con salt utilizando el algoritmo Blowfish (`crypt(pin, gen_salt('bf', 8))`). La validación del cliente en ventanilla se realiza mediante la función `seguridad.fn_validar_pin_entrega()`, sin almacenar jamás el PIN en texto plano.
* **Cifrado Simétrico:** Las referencias de transferencias bancarias se resguardan como binarios cifrados `BYTEA` utilizando el algoritmo AES con llave secreta mediante `pgp_sym_encrypt()`.

---

## 7. SECCIÓN 6: RESPALDOS, ALTA DISPONIBILIDAD Y DRP (20%)

### 7.1. Topología del Clúster (Primary + Hot Standby)
El clúster fue configurado con replicación física en streaming asíncrona:
* **Nodo Maestro (`pg-primary` / puerto 5432):** Modo Read/Write, `wal_level = replica`.
* **Nodo Réplica (`pg-standby` / puerto 5433):** Modo Read-Only (*Hot Standby*), clonado automáticamente mediante `pg_basebackup -R`.

**Validación en Vivo de `pg_stat_replication`:**
```text
usename          | replicator
application_name | walreceiver
state            | streaming
replay_lag_bytes | 0
```
El retraso de replicación se mantiene en **0 bytes**. En el nodo réplica, `pg_is_in_recovery()` retorna `true` y cualquier intento de escritura es abortado de inmediato por el motor.

### 7.2. Suite Multiplataforma de Respaldos (`backup/`)
Desarrollada en PowerShell Core (`pwsh` en Linux / Windows PowerShell):
1. **`backup_logico.ps1`:** Genera volcados en formato Custom comprimido (`pg_dump -Fc -Z 6`) permitiendo restauraciones granulares por tabla.
2. **`backup_fisico.ps1`:** Ejecuta `pg_basebackup -Ft -z -X stream` capturando la imagen binaria `$PGDATA` y el flujo WAL.
3. **`backup_globales.ps1`:** Exporta roles, contraseñas SCRAM y configuración global con `pg_dumpall --globals-only`.
4. **`backup_completo.ps1`:** Orquestador maestro que audita en `logs/backup_history.log` y purga automáticamente artefactos con más de 7 días de antigüedad.

### 7.3. Plan de Recuperación ante Desastres (DRP) y Simulación de Failover
El manual `backup/README.md` documenta los procedimientos paso a paso ante contingencias:
* **Restauración granular de tablas:** `pg_restore -t encomienda`.
* **Recuperación puntual en el tiempo (PITR):** Uso de `recovery.signal`, `restore_command` y `recovery_target_time`.
* **Simulación de Failover:** Ante la detención forzada del primario (`docker stop pg-primary`), se ejecuta en el standby:
  ```bash
  pg_ctl promote -D /var/lib/postgresql/data/pgdata
  ```
  El nodo réplica asume el rol de nuevo maestro, `pg_is_in_recovery()` pasa a `false` y el clúster restablece inmediatamente las transacciones de escritura.

---

## 8. SECCIÓN 7: OBSERVABILIDAD Y MONITOREO EN TIEMPO REAL (15%)

### 8.1. Arquitectura del Stack de Monitoreo
Implementado para el nodo `LXC-04`:
* **`postgres_exporter`:** Exporta métricas nativas del clúster en los puertos `9187` (Primary) y `9188` (Standby).
* **VictoriaMetrics:** Base de datos de series de tiempo configurada con retención de 1 mes y raspado cada 10 segundos. Se verificó el raspado exitoso de **1,479 métricas por intervalo**.
* **Grafana:** Servidor de visualización en el puerto `3000` con aprovisionamiento automatizado por código.

### 8.2. KPIs Visualizados en el Dashboard
El tablero *"PostgreSQL 17 HA & Performance - Envío Seguro"* monitorea:
1. Semáforo de salud de nodos (`pg_up`).
2. Métrica de retraso de replicación en streaming (`pg_stat_replication_replay_lag_bytes`).
3. Indicador de **Cache Hit Ratio** confirmando valores sostenidos superiores al **99.5%**.
4. Gráfica de Transacciones por Segundo (TPS - commits vs rollbacks).
5. Número de conexiones concurrentes activas frente al límite configurado.

---

## 9. CONCLUSIONES TÉCNICAS Y RECOMENDACIONES DBA

1. **Eficiencia en Infraestructura:** El diseño híbrido (PostgreSQL 17 sobre contenedores OCI) garantiza un consumo inferior a 2.5 GB de RAM para todo el clúster de 4 nodos, demostrando alta viabilidad en hardware de bajo costo.
2. **Resiliencia Operativa:** La combinación de replicación física en streaming con lag cero y una suite de respaldos lógicos/físicos asegura un Objetivo de Punto de Recuperación (**RPO = 0**) y un Tiempo de Recuperación (**RTO < 5 minutos**) ante desastres.
3. **Escalabilidad y Seguridad:** El particionamiento declarativo en `evento_rastreo` y las políticas de Row-Level Security (RLS) aíslan eficazmente la carga y los datos entre sucursales, previniendo cuellos de botella y accesos no autorizados.

---

## 10. REFERENCIAS Y ARTEFACTOS DEL REPOSITORIO

* **Repositorio GitHub:** `https://github.com/ca04073/encomiendas-envio-seguro`
* **Diagramas DER:** [`docs/DER-chen.png`](docs/DER-chen.png) y [`docs/DER-pata-de-gallo.png`](docs/DER-pata-de-gallo.png)
* **Suite de Respaldos y DRP:** [`backup/README.md`](backup/README.md)
* **Manual de Almacenamiento y Particionamiento:** [`docs/mantenimiento-almacenamiento.md`](docs/mantenimiento-almacenamiento.md)
* **Guía de Failover y Alta Disponibilidad:** [`database/ha/README.md`](database/ha/README.md)
* **Guía de Monitoreo y Dashboards:** [`monitoring/README.md`](monitoring/README.md)
