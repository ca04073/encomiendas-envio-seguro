# 📊 Módulo de Observabilidad, Monitoreo y Alertas DBA

**Proyecto:** Encomiendas "Envío Seguro"  
**Cátedra:** Administración de Bases de Datos (ADB135) — Universidad de El Salvador  
**Ponderación Rúbrica:** 15% (Seguridad, monitoreo y alertas)  
**Stack Tecnológico:** VictoriaMetrics + Grafana + `postgres_exporter`

---

## 1. Arquitectura de Observabilidad

El stack de observabilidad está diseñado para operar con una huella de memoria mínima (~250 MB RAM total), haciéndolo ideal para la infraestructura ligera en contenedores LXC de Proxmox VE (`LXC-04`):

```text
┌───────────────────────┐             ┌───────────────────────┐
│     LXC-01: Primary   │             │     LXC-02: Standby   │
│   postgres_exporter   │             │   postgres_exporter   │
│   (Métricas :9187)    │             │   (Métricas :9187)    │
└───────────┬───────────┘             └───────────┬───────────┘
            │                                     │
            └──────────────────┬──────────────────┘
                               │ Scrape HTTP cada 10s
                               ▼
            ┌─────────────────────────────────────┐
            │        LXC-04: mon-stack            │
            │                                     │
            │  • VictoriaMetrics (:8428)          │
            │    Base de datos de series de tiempo│
            │                                     │
            │  • Grafana (:3000)                  │
            │    Dashboards interactivos          │
            └─────────────────────────────────────┘
```

---

## 2. Métricas Clave Monitoreadas (KPIs de DBA)

| Métrica | Consulta PromQL | Umbral de Alerta / Objetivo | Propósito Operativo |
| :--- | :--- | :---: | :--- |
| **Salud de Nodos** | `pg_up` | `== 1` (Verde) | Detecta caídas inmediatas del primario o de la réplica standby. |
| **Lag de Replicación** | `pg_replication_lag` o LSN diff | `< 1 MB` / `< 2s` | Alerta si la réplica se atrasa en aplicar los registros WAL. |
| **Cache Hit Ratio** | `blks_hit / (blks_hit + blks_read) * 100` | `> 99.0%` | Verifica que las consultas se resuelvan en memoria RAM sin ir a disco. |
| **TPS (Commits)** | `rate(pg_stat_database_xact_commit[1m])` | Informativo | Mide la carga transaccional por segundo de la empresa. |
| **Rollbacks / seg** | `rate(pg_stat_database_xact_rollback[1m])` | `> 5 / s` (Alerta) | Detecta errores de aplicación o transacciones abortadas. |
| **Conexiones Activas** | `pg_stat_activity_count` | `< 85` (Max: 100) | Previene la saturación del pool de conexiones del motor. |

---

## 3. Acceso y Uso de Grafana

Una vez levantado el stack:

* **URL:** `http://localhost:3000` (o `http://<IP_LXC_04>:3000`)
* **Usuario:** `admin`
* **Contraseña:** `admin` (solicitará cambio opcional en primer inicio)
* **Tablero Preconfigurado:** Ingresar a *Dashboards* $\rightarrow$ Carpeta *Envío Seguro DBA* $\rightarrow$ **PostgreSQL 17 HA & Performance - Envío Seguro**.

---

## 4. Evidencias para el Informe Técnico Final (Capturas Requeridas)

Para la sección de *Monitoreo y Alertas* del informe de 7–10 páginas, se deben capturar los siguientes paneles de Grafana:

1. **Captura del Panel de Estado del Clúster:** Mostrando ambos nodos en estado `UP` (Primario en verde y Standby en verde con lag de 0 bytes).
2. **Captura del Panel de Rendimiento Transaccional:** Gráfica de picos de Commits/segundo generados durante la prueba masiva de inserciones.
3. **Captura de Cache Hit Ratio:** Mostrando el indicador en $> 99.5\%$ confirmando la efectividad de los índices B-Tree y parciales configurados en la fase de optimización.
