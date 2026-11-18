# 📊 Manual de Gestión de Almacenamiento, Particionamiento y Mantenimiento DBA

**Proyecto:** Encomiendas "Envío Seguro"  
**Cátedra:** Administración de Bases de Datos (ADB135) — Universidad de El Salvador  
**Motor:** PostgreSQL 17  
**Ponderación Rúbrica:** 10% (Almacenamiento y Mantenibilidad) + 10% (Rendimiento y Optimización)

---

## 1. Introducción y Objetivos

Este documento da cumplimiento estricto a las **Indicaciones del Requerimiento 3 y Criterios de Rendimiento**, especificando cómo la arquitectura de base de datos de "Envío Seguro" gestiona el crecimiento de datos a escala empresarial, optimiza el espacio físico en disco y previene la degradación del rendimiento mediante:

1. **Particionamiento declarativo por rangos temporales** en tablas críticas.
2. **Estrategia de indexación avanzada** con índices compuestos y parciales.
3. **Proyección volumétrica de crecimiento** a 1 y 3 años.
4. **Políticas de afinamiento de `AUTOVACUUM`** y control de fragmentación (*bloat*).
5. **Ciclo de vida y depuración de datos históricos** (*Data Archiving & Purging*).

---

## 2. Estrategia de Particionamiento Declarativo (`evento_rastreo`)

### 2.1. Justificación de la Tabla Seleccionada
La tabla **`evento_rastreo`** es el corazón transaccional del sistema de encomiendas:
* Cada encomienda genera en promedio de **4 a 6 eventos** a lo largo de su ciclo de vida (Recepción, Tránsito, Sucursal Destino, Reparto, Entrega o Incidencia).
* En un escenario operativo de 1,000 envíos diarios, se generan entre **120,000 y 180,000 registros al mes**, convirtiéndola en la candidata ideal para particionamiento.

### 2.2. Esquema de Particionado Implementado
Se adoptó un esquema **`PARTITION BY RANGE (fecha_hora)`** con particiones mensuales para la operación caliente y trimestrales/default para contingencia:

| Nombre de Partición | Rango de Fechas Cubierto | Propósito / Tipo de Carga | Registros Actuales |
| :--- | :--- | :--- | :---: |
| `evento_rastreo_2026_01` | `[2026-01-01, 2026-02-01)` | Operación histórica Enero 2026 | 1,464 |
| `evento_rastreo_2026_02` | `[2026-02-01, 2026-03-01)` | Operación activa Febrero 2026 | 536 |
| `evento_rastreo_2026_03` | `[2026-03-01, 2026-04-01)` | Ventana operativa Marzo 2026 | 0 |
| `evento_rastreo_2026_q2` | `[2026-04-01, 2026-07-01)` | Segundo Trimestre 2026 | 0 |
| `evento_rastreo_2026_q3` | `[2026-07-01, 2026-10-01)` | Tercer Trimestre 2026 | 0 |
| `evento_rastreo_2026_q4` | `[2026-10-01, 2027-01-01)` | Cuarto Trimestre 2026 | 0 |
| `evento_rastreo_2027_q1` | `[2027-01-01, 2027-04-01)` | Proyección año siguiente | 0 |
| `evento_rastreo_default` | Valores fuera de rango | Partición de salvaguarda (Catch-All) | 0 |

### 2.3. Evidencia de Optimización: Podado de Particiones (*Partition Pruning*)

Cuando una consulta incluye un filtro sobre la columna de corte `fecha_hora`, el planificador de PostgreSQL descarta (*prunes*) las particiones irrelevantes en tiempo de planificación, evitando lecturas de disco innecesarias:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM evento_rastreo
WHERE fecha_hora >= '2026-02-01 00:00:00' AND fecha_hora < '2026-02-15 00:00:00';
```

**Resultado de Ejecución en Vivo:**
```text
Seq Scan on evento_rastreo_2026_02 evento_rastreo  (cost=0.00..7.53 rows=1 width=446) 
                                                   (actual time=0.018..0.108 rows=536 loops=1)
  Filter: ((fecha_hora >= '2026-02-01') AND (fecha_hora < '2026-02-15'))
  Buffers: shared hit=6
Planning Time: 2.789 ms
Execution Time: 0.166 ms
```
> **Análisis DBA:** En lugar de escanear los 2,000 registros del clúster, el motor consultó únicamente la partición de febrero (`evento_rastreo_2026_02`), completando la consulta en tan solo **0.166 milisegundos**.

### 2.4. Mantenimiento Automatizado de Nuevas Particiones
Para evitar fallos en la inserción conforme avanza el calendario, se implementó la función almacenada:

```sql
SELECT fn_crear_particion_evento(2027, 2);
-- Retorna: Partición evento_rastreo_2027_02 creada exitosamente para rango [2027-02-01 - 2027-03-01).
```

---

## 3. Estrategia de Índices de Alto Rendimiento

### 3.1. Índices Compuestos Estratégicos
* **`idx_guia_envio_emision` (`fecha_emision, tipo_cobro`):** Acelera los cierres de caja y conciliaciones contables diarias.
* **`idx_pago_guia_estado` (`id_guia, estado_pago`):** Optimiza las comprobaciones de pago en ventanilla antes de la entrega del paquete.
* **`idx_cliente_identificacion` (`dui, nit`):** Búsqueda instantánea de clientes corporativos y particulares durante el registro de encomienda.

### 3.2. Índices Parciales (*Partial Indexes*)
Un índice B-Tree tradicional indexa el 100% de las filas de una tabla. Los **índices parciales** utilizan una cláusula `WHERE` para incluir únicamente las filas de interés operativo activo, reduciendo el tamaño del índice en hasta un **85%**:

1. **`idx_pago_pendientes_parcial`:**
   ```sql
   CREATE INDEX idx_pago_pendientes_parcial ON pago (id_pago, id_guia, monto, fecha_pago)
   WHERE estado_pago = 'Pendiente';
   ```
   * *Justificación:* En un sistema real, el 95% de los pagos están en estado 'Pagado'. Indexar solo los 'Pendientes' mantiene el índice en unos pocos kilobytes en la memoria caché RAM (`shared_buffers`).

2. **`idx_incidencias_activas_parcial`:**
   ```sql
   CREATE INDEX idx_incidencias_activas_parcial ON incidencia (id_incidencia, id_encomienda, prioridad)
   WHERE estado IN ('Abierta', 'En proceso');
   ```

**Evidencia de Plan de Ejecución (`EXPLAIN ANALYZE`):**
```text
Bitmap Heap Scan on pago  (cost=8.24..13.49 rows=20 width=22) (actual time=0.122..0.155 rows=20)
  Recheck Cond: (estado_pago = 'Pendiente')
  Buffers: shared hit=5 read=1
  ->  Bitmap Index Scan on idx_pago_pendientes_parcial  (actual time=0.081..0.082 rows=20)
        Buffers: shared read=1
Execution Time: 0.302 ms
```
> **Análisis DBA:** La consulta resolvió los 20 pagos pendientes leyendo **un único bloque de disco (`read=1`)** gracias al índice parcial especializado.

---

## 4. Proyección Volumétrica y Crecimiento en Disco

### 4.1. Estimación de Huella de Almacenamiento por Registro

| Entidad / Tabla | Tamaño Promedio por Fila (Bytes) | Frecuencia de Inserción Diaria (Estimada) | Crecimiento Diario (KB) |
| :--- | :---: | :---: | :---: |
| `agencia` / `sucursal` | ~180 B | Estática (Mantenimiento) | Despreciable |
| `cliente` | ~240 B | 50 clientes nuevos / día | 12.0 KB |
| `encomienda` | ~210 B | 500 envíos / día | 105.0 KB |
| `guia_envio` | ~120 B | 500 guías / día | 60.0 KB |
| **`evento_rastreo` (Particionada)** | **~110 B** | **2,500 eventos / día (5 por envío)** | **275.0 KB** |
| `pago` | ~90 B | 500 pagos / día | 45.0 KB |
| `documento_dte` + `detalle_dte` | ~380 B | 500 DTEs / día | 190.0 KB |
| `incidencia` | ~280 B | 15 incidencias / día | 4.2 KB |
| **Total Datos Netos:** | — | — | **~686.2 KB / día** |

### 4.2. Proyección de Crecimiento a 1 y 3 Años

Considerando un factor de sobrecarga (*overhead*) del **100%** por concepto de índices B-Tree, tablas de particionamiento, metadatos de PostgreSQL y archivos WAL:

* **Tasa mensual neta:** $\approx 20.6\text{ MB / mes}$ (datos) $+ 20.6\text{ MB}$ (índices) $= 41.2\text{ MB / mes}$.
* **Proyección a 6 Meses:** $\approx 250\text{ MB}$ de almacenamiento total.
* **Proyección a 1 Año:** $\approx 500\text{ MB}$ de datos operativos.
* **Proyección a 3 Años:** $\approx 1.6\text{ GB}$ a escala nominal (o $\approx 5\text{ GB}$ considerando un crecimiento comercial del 200%).

> **Conclusión de Infraestructura:** El disco de **8 GB** asignado en el nodo `LXC-01` (`pg-primary`) garantiza holgura operativa para más de **5 años de operación continua** sin riesgo de saturación de almacenamiento.

---

## 5. Políticas de Mantenimiento y Afinamiento de `AUTOVACUUM`

Para evitar el fenómeno de *Table Bloat* (espacio muerto acumulado por tuplas muertas producto de `UPDATE` y `DELETE` frecuentes):

### 5.1. Configuración Personalizada para Tablas Calientes
Por defecto, PostgreSQL ejecuta autovacuum cuando el 20% de la tabla cambia (`scale_factor = 0.2`). En tablas con millones de filas, esperar al 20% es inaceptable.

Se aplican parámetros agresivos en `evento_rastreo` y `pago`:

```sql
-- Ejecutar autovacuum cuando cambie más del 5% o 500 filas
ALTER TABLE evento_rastreo SET (
    autovacuum_vacuum_scale_factor = 0.05,
    autovacuum_vacuum_threshold = 500,
    autovacuum_analyze_scale_factor = 0.02
);

ALTER TABLE pago SET (
    autovacuum_vacuum_scale_factor = 0.05,
    autovacuum_vacuum_threshold = 200
);
```

### 5.2. Monitoreo de Tuplas Muertas (*Dead Tuples*)
Consulta de diagnóstico periódica para el DBA:

```sql
SELECT 
    relname AS tabla,
    n_live_tup AS tuplas_vivas,
    n_dead_tup AS tuplas_muertas,
    ROUND(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS porcentaje_muerto,
    last_autovacuum,
    last_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;
```

---

## 6. Estrategia de Depuración y Archivado Histórico (*Data Lifecycle*)

Gracias al particionamiento declarativo, la depuración de datos antiguos **no requiere ejecutar `DELETE` masivos** (lo cual generaría saturación en el log WAL y bloqueos de tabla):

```bash
# 1. Desconectar la partición antigua de forma instantánea (DDL metadata only)
ALTER TABLE evento_rastreo DETACH PARTITION evento_rastreo_2026_01;

# 2. Exportar la partición desconectada a almacenamiento secundario/comprimido
pg_dump -t evento_rastreo_2026_01 -Fc -f /backup/historico_2026_01.dump envio_seguro

# 3. Liberar el espacio en disco inmediatamente
DROP TABLE evento_rastreo_2026_01;
```

Este procedimiento garantiza que la liberación de espacio en disco sea **inmediata, con tiempo de bloqueo cero y sin impacto en el rendimiento de los usuarios concurrentes**.
