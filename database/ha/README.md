# 🛡️ Guía de Alta Disponibilidad (HA), Replicación en Streaming y Simulación de Failover

**Proyecto:** Encomiendas "Envío Seguro"  
**Cátedra:** Administración de Bases de Datos (ADB135) — Universidad de El Salvador  
**Motor:** PostgreSQL 17  
**Ponderación en Rúbrica:** 20% (Respaldos, recuperación y alta disponibilidad) + 15% (Informe Técnico)

---

## 1. Topología del Clúster Contenedorizado

El clúster está orquestado mediante `compose.yaml` emulando la topología de los nodos LXC de Proxmox VE:

```text
                     [ Red Docker / Podman Bridge ]
                                   │
         ┌─────────────────────────┴─────────────────────────┐
         ▼                                                   ▼
┌─────────────────────────────────┐         ┌─────────────────────────────────┐
│       pg-primary (Master)       │         │    pg-standby (Hot Standby)     │
│   Puerto Host: 5432             │         │   Puerto Host: 5433             │
│   Modo: Read / Write            │         │   Modo: Read-Only (Hot Standby) │
│   wal_level: replica            │         │   clonado vía: pg_basebackup    │
└────────────────┬────────────────┘         └────────────────▲────────────────┘
                 │                                           │
                 └────── Streaming WAL (replicator) ─────────┘
```

---

## 2. Evidencias y Capturas para el Informe Técnico Final (7–10 Páginas)

La rúbrica y las indicaciones exigen **evidencias comprobables** (capturas de terminal o queries) en el informe técnico. A continuación se detallan las **5 capturas clave** que deben incluirse:

### 📸 Captura 1: Replicación en Streaming Activa
**Objetivo:** Demostrar que el nodo primario reconoce al standby y transmite registros WAL con lag cero.

**Comando a ejecutar:**
```bash
docker exec -it pg-primary psql -U postgres -d envio_seguro -x -f /docker-entrypoint-initdb.d/../ha/verificar_replicacion.sql
```
*O directamente vía query:*
```bash
docker exec -it pg-primary psql -U postgres -d envio_seguro -x -c "
SELECT pid, usename, application_name, client_addr, state, sync_state,
       sent_lsn, write_lsn, flush_lsn, replay_lsn,
       pg_wal_lsn_diff(sent_lsn, replay_lsn) AS replay_lag_bytes
FROM pg_stat_replication;
"
```
> **Qué debe verse en la captura:** `usename = replicator`, `state = streaming`, `replay_lag_bytes = 0`.

---

### 📸 Captura 2: Estado Hot Standby y Protección de Solo Lectura
**Objetivo:** Evidenciar que el nodo réplica está en modo recuperación y rechaza transacciones DDL/DML.

**Comando a ejecutar:**
```bash
docker exec -it pg-standby psql -U postgres -d envio_seguro -c "
SELECT pg_is_in_recovery() AS is_hot_standby;
"
```
**Prueba de denegación de escritura:**
```bash
docker exec -it pg-standby psql -U postgres -d envio_seguro -c "
CREATE TABLE intento_escritura (id int);
"
```
> **Qué debe verse en la captura:** `is_hot_standby = t` y el error `ERROR: cannot execute CREATE TABLE in a read-only transaction`.

---

### 📸 Captura 3: Replicación de Datos en Tiempo Real
**Objetivo:** Comprobar que una transacción confirmada en el primario se propaga instantáneamente a la réplica.

1. **Insertar un registro de prueba en el primario:**
   ```bash
   docker exec -it pg-primary psql -U postgres -d envio_seguro -c "
   INSERT INTO metodo_pago (nombre, descripcion) VALUES ('Pago QR Chivo', 'Billetera digital El Salvador');
   "
   ```
2. **Consultar inmediatamente en el standby:**
   ```bash
   docker exec -it pg-standby psql -U postgres -d envio_seguro -c "
   SELECT id_metodo_pago, nombre, descripcion FROM metodo_pago WHERE nombre = 'Pago QR Chivo';
   "
   ```
> **Qué debe verse en la captura:** El registro aparece idéntico en el standby sin haber sido escrito directamente en él.

---

### 📸 Captura 4: Simulación de Caída del Primario (Desastre)
**Objetivo:** Simular la falla de hardware o caída del nodo `pg-primary`.

**Comando:**
```bash
docker stop pg-primary
```
*Verificar que `pg-standby` sigue encendido y respondiendo consultas de lectura:*
```bash
docker exec -it pg-standby psql -U postgres -d envio_seguro -c "SELECT count(*) FROM encomienda;"
```

---

### 📸 Captura 5: Promoción del Standby a Nuevo Primario (Failover)
**Objetivo:** Promover la réplica para que tome el rol de Primary y comience a aceptar operaciones de escritura.

**Comando de promoción:**
```bash
docker exec -it pg-standby pg_ctl promote -D /var/lib/postgresql/data/pgdata
```
**Validación de nuevo estado Read/Write:**
```bash
docker exec -it pg-standby psql -U postgres -d envio_seguro -c "
SELECT pg_is_in_recovery() AS is_in_recovery;
INSERT INTO metodo_pago (nombre, descripcion) VALUES ('Pago Bitcoin Lightning', 'Red Lightning Network');
SELECT id_metodo_pago, nombre FROM metodo_pago WHERE nombre = 'Pago Bitcoin Lightning';
"
```
> **Qué debe verse en la captura:** `is_in_recovery = f` (false) y el `INSERT 0 1` ejecutado con éxito en el antiguo standby, demostrando la continuidad operativa del negocio ante desastres.

---

## 3. Comandos Rápidos de Gestión

| Acción | Comando |
| :--- | :--- |
| **Levantar todo el clúster HA** | `podman compose up -d` |
| **Ver logs del Primario** | `podman logs -f pg-primary` |
| **Ver logs del Standby** | `podman logs -f pg-standby` |
| **Verificar replicación** | `docker exec -it pg-primary psql -U postgres -d envio_seguro -f /home/database/ha/verificar_replicacion.sql` |
| **Reiniciar nodo réplica limpio** | `podman volume rm encomiendas-envio-seguro_pg_standby_data && podman compose up -d pg-standby` |
