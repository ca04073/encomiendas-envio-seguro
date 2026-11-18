# 🔐 Ficha de Accesos, Credenciales y Conexión al Clúster
## Sistema de Encomiendas "Envío Seguro"
**Cátedra:** Administración de Bases de Datos (ADB135) — Ciclo II 2026  
**Institución:** Universidad de El Salvador, Facultad Multidisciplinaria de Occidente  
**Escenario de Evaluación:** 10 — Encomiendas y Envíos Nacionales  

---

## 1. Tabla Maestra de Credenciales y Cuentas

| Rol / Servicio | Usuario | Contraseña | Puerto | Nivel de Privilegios | Propósito Operativo |
| :--- | :--- | :--- | :---: | :--- | :--- |
| **DBA / Superusuario** | `postgres` | `postgres` | `5432` | Superuser / Control Total | Administración del clúster, DDL, respaldos y mantenimiento. |
| **Réplica Standby (Lectura)**| `postgres` | `postgres` | `5433` | Read-Only (Hot Standby) | Consultas analíticas y reportes sin sobrecargar el primario. |
| **Usuario de Replicación** | `replicator` | `ReplPasswordSeguro123` | `5432` | Replication | Streaming binario de WAL y clonación física `pg_basebackup`. |
| **Operador San Salvador** | `usr_operador_ss` | `OperadorSS123!` | `5432` | Operador (RLS Sucursal 1)| Pruebas de seguridad RLS: ve únicamente 71 encomiendas de San Salvador. |
| **Operador Santa Ana** | `usr_operador_sa` | `OperadorSA123!` | `5432` | Operador (RLS Sucursal 2)| Pruebas de seguridad RLS: ve únicamente 72 encomiendas de Santa Ana. |
| **Auditor Fiscal / Tributario**| `usr_auditor_fiscal` | `AuditorFiscal123!` | `5432` | Auditor (Solo Lectura) | Consulta consolidada de facturación DTE e historial sin bypass DBA. |
| **Grafana Dashboard** | `admin` | `admin` | `3000` | Administrador Web | Monitoreo visual de rendimiento, conexiones, CPU y transacciones. |
| **VictoriaMetrics (TSDB)** | *(N/A)* | *(Sin clave interna)* | `8428` | Almacenamiento Métricas | Motor de series temporales para ingesta de métricas de PostgreSQL. |

---

## 2. Parámetros de Conexión para Clientes Gráficos (DBeaver / pgAdmin / DataGrip)

### Perfil A: Conexión Principal (Lectura y Escritura)
- **Host / Servidor:** IP de Proxmox (ej. `192.168.0.X` o `192.168.1.150` / `localhost`)
- **Puerto:** `5432`
- **Base de Datos:** `envio_seguro`
- **Usuario:** `postgres`
- **Contraseña:** `postgres`
- **Modo SSL:** Deshabilitado (`disable` o `prefer`)

### Perfil B: Conexión a la Réplica en Tiempo Real (Solo Lectura)
- **Host / Servidor:** Misma IP del servidor
- **Puerto:** `5433` *(redirige internamente a la réplica standby)*
- **Base de Datos:** `envio_seguro`
- **Usuario:** `postgres`
- **Contraseña:** `postgres`

---

## 3. URLs de Monitoreo y Observabilidad Web

- **Grafana (Tablero DBA en Vivo):**
  - URL: `http://<IP-DEL-SERVIDOR>:3000`
  - Usuario: `admin`
  - Contraseña: `admin`
  - *Tableros pre-cargados:* "PostgreSQL Database ADB" con métricas de transacciones/seg, tamaño de base, caché hit ratio y estado de replicación.

- **VictoriaMetrics (API / Explorador de Métricas):**
  - URL: `http://<IP-DEL-SERVIDOR>:8428`

---

## 4. Comandos Rápidos de Verificación para la Defensa

### A. Probar la Réplica en Caliente (Hot Standby)
```bash
sudo docker exec -it pg-standby psql -U postgres -d envio_seguro -c "SELECT pg_is_in_recovery();"
```
> **Resultado esperado:** `t` (True). Confirma que el nodo réplica está activo y recibiendo transacciones por streaming.

### B. Probar el Aislamiento por Sucursal (Row-Level Security - RLS)
```bash
sudo docker exec -it pg-primary psql -U postgres -d envio_seguro -c "
SET ROLE usr_operador_ss;
SELECT count(*) AS encomiendas_san_salvador FROM encomienda;
SET ROLE usr_operador_sa;
SELECT count(*) AS encomiendas_santa_ana FROM encomienda;
RESET ROLE;
SELECT count(*) AS total_consolidado_dba FROM encomienda;
"
```
> **Resultado esperado:** San Salvador muestra **71**, Santa Ana muestra **72** y el DBA muestra **500**.

### C. Probar la Velocidad del Particionamiento (Partition Pruning)
```bash
sudo docker exec -it pg-primary psql -U postgres -d envio_seguro -c "
EXPLAIN ANALYZE 
SELECT count(*) FROM evento_rastreo 
WHERE fecha_hora >= '2026-01-01' AND fecha_hora < '2026-02-01';
"
```
> **Resultado esperado:** Ejecución en menos de 0.1 ms escaneando únicamente la partición mensual `evento_rastreo_2026_01`.

---

## 5. Topología de Red en Proxmox VE

| CT ID | Hostname | IP Red Interna (`eth1`) | Rol en el Clúster |
| :---: | :--- | :--- | :--- |
| **`350`** | `db-primary` | `192.168.1.150` | PostgreSQL 17 Master + Exporter (:5432 / :9187) |
| **`355`** | `db-standby` | `192.168.1.155` | Réplica Streaming + Exporter (:5433 / :9188) |
| **`360`** | `db-monitor` | `192.168.1.160` | VictoriaMetrics (:8428) + Grafana (:3000) |
| **`365`** | `db-backup` | `192.168.1.165` | Servidor de Almacenamiento Seguro de Respaldos |
