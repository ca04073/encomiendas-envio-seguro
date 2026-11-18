# 🛡️ Módulo de Respaldos y Plan de Recuperación ante Desastres (DRP)

**Proyecto:** Encomiendas "Envío Seguro"  
**Cátedra:** Administración de Bases de Datos (ADB135) — Universidad de El Salvador  
**Motor:** PostgreSQL 17  
**Entorno de Ejecución:** PowerShell Core (`pwsh`) en Linux / LXC o Windows PowerShell 5.1+  

---

## 1. Descripción General del Módulo

Este módulo cubre el **20% de la ponderación de la rúbrica oficial** correspondiente a *Respaldos, recuperación y alta disponibilidad*. Proporciona una suite parametrizable y multiplataforma compuesta por cuatro scripts PowerShell diseñados para operar de forma remota contra el nodo primario (`LXC-01`) o de manera local en contenedores.

### Estructura de Directorios

```text
backup/
├── backup_logico.ps1       # Respaldo lógico comprimido (-Fc -Z 6) de 'envio_seguro'
├── backup_fisico.ps1       # Respaldo físico base + WAL (-Ft -z -X stream)
├── backup_globales.ps1     # Respaldo de roles, contraseñas y permisos del servidor
├── backup_completo.ps1     # Orquestador maestro + retención (7 días) + auditoría
├── logs/
│   └── backup_history.log  # Bitácora histórica con tiempos, tamaños y estados
├── storage/
│   ├── logico/             # Archivos .dump (pg_dump)
│   ├── fisico/             # Directorios basebackup_* (base.tar.gz y pg_wal.tar.gz)
│   └── globales/           # Archivos .sql (pg_dumpall)
└── README.md               # Este manual técnico y procedimientos DRP
```

---

## 2. Matriz Comparativa de Estrategias de Respaldo

| Estrategia | Herramienta | Formato | Alcance | Caso de Uso Principal |
| :--- | :--- | :---: | :--- | :--- |
| **Globales** | `pg_dumpall --globals-only` | `.sql` (Texto) | Roles, usuarios, contraseñas SCRAM, tablespaces. | Reconstrucción de seguridad y permisos ante migración o desastre total. |
| **Lógico** | `pg_dump -Fc -Z 6` | `.dump` (Custom Binario) | Esquema completo, datos, triggers, secuencias de `envio_seguro`. | Restauraciones granulares por tabla, cambios accidentales o recuperación rápida. |
| **Físico** | `pg_basebackup -Ft -z -X stream` | `.tar.gz` (Físico) | Copia binaria idéntica del directorio `$PGDATA` y flujo de transacciones WAL. | Recuperación ante falla catastrófica de hardware/nodo y clonación de réplicas Standby. |

---

## 3. Guía de Ejecución de los Scripts

### 3.1. Requisitos Previos y Variables de Entorno

Los scripts aceptan parámetros de línea de comandos o leen las variables estándar de PostgreSQL en el entorno:

```powershell
# En Linux/LXC con PowerShell Core (pwsh):
$env:PGHOST = "192.168.1.10"
$env:PGPORT = "5432"
$env:PGUSER = "postgres"
$env:PGPASSWORD = "TuPasswordSeguro123"
$env:PGUSER_REPL = "replicator"
$env:PGPASSWORD_REPL = "ReplPasswordSeguro123"
```

### 3.2. Ejecución Individual

```powershell
# 1. Respaldo de roles y objetos globales
./backup_globales.ps1 -PgHost "192.168.1.10" -PgUser "postgres"

# 2. Respaldo lógico comprimido
./backup_logico.ps1 -PgHost "192.168.1.10" -PgDatabase "envio_seguro" -CompressionLevel 6

# 3. Respaldo físico del clúster (requiere usuario con atributo REPLICATION)
./backup_fisico.ps1 -PgHost "192.168.1.10" -PgUser "replicator"
```

### 3.3. Ejecución del Orquestador Maestro (`backup_completo.ps1`)

Ejecuta las tres fases en orden, valida los códigos de retorno, purga respaldos anteriores a la política de retención y genera el resumen consolidado:

```powershell
# Ejecución estándar con retención de 7 días
./backup_completo.ps1 -RetentionDays 7 -PgHost "192.168.1.10"

# Ejecución rápida omitiendo respaldo físico pesado (solo lógico y globales)
./backup_completo.ps1 -SkipPhysical
```

---

## 4. Manual de Recuperación ante Desastres (Disaster Recovery Plan - DRP)

### 4.1. Escenario A: Restauración de Roles y Permisos Globales

Si se reinstala el clúster o se corrompieron cuentas de usuario:

```bash
# Conectado como superusuario al nodo destino
psql -h localhost -p 5432 -U postgres -f storage/globales/globales_YYYYMMDD_HHMMSS.sql
```

---

### 4.2. Escenario B: Restauración Lógica Completa de la Base de Datos

Si la base `envio_seguro` sufrió corrupción lógica o pérdida de datos:

```bash
# 1. Terminar conexiones activas y recrear la base limpia
psql -h localhost -U postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'envio_seguro' AND pid <> pg_backend_pid();"
psql -h localhost -U postgres -c "DROP DATABASE IF EXISTS envio_seguro;"
psql -h localhost -U postgres -c "CREATE DATABASE envio_seguro ENCODING 'UTF8';"

# 2. Restaurar con pg_restore en paralelo (-j 4)
pg_restore -h localhost -p 5432 -U postgres -d envio_seguro -v -j 4 storage/logico/envio_seguro_logico_YYYYMMDD_HHMMSS.dump
```

---

### 4.3. Escenario C: Restauración Granular de una Tabla Específica

Si un error humano eliminó o modificó registros únicamente en la tabla `encomienda` o `cliente`:

```bash
# Restaurar únicamente la tabla 'encomienda' sin sobreescribir el resto de la base
pg_restore -h localhost -U postgres -d envio_seguro -t encomienda --clean --if-exists storage/logico/envio_seguro_logico_YYYYMMDD_HHMMSS.dump
```

---

### 4.4. Escenario D: Recuperación Físico-Catastrófica del Servidor Primario

Si el nodo maestro (`LXC-01`) se destruye por completo y se debe reconstruir desde un respaldo de `LXC-03`:

1. **Detener el servicio de PostgreSQL en el nuevo nodo:**
   ```bash
   systemctl stop postgresql
   # O si corre bajo Docker:
   docker stop pg-primary
   ```

2. **Vaciar el directorio de datos corrupto/antiguo:**
   ```bash
   rm -rf /var/lib/postgresql/data/*
   ```

3. **Extraer los archivos del respaldo físico:**
   ```bash
   cd /var/lib/postgresql/data
   tar -xzvf /ruta/al/respaldo/basebackup_YYYYMMDD_HHMMSS/base.tar.gz -C .
   mkdir -p pg_wal
   tar -xzvf /ruta/al/respaldo/basebackup_YYYYMMDD_HHMMSS/pg_wal.tar.gz -C pg_wal/
   ```

4. **Ajustar permisos y levantar el servidor:**
   ```bash
   chown -R postgres:postgres /var/lib/postgresql/data
   chmod 700 /var/lib/postgresql/data
   docker start pg-primary
   ```

---

### 4.5. Escenario E: Point-In-Time Recovery (PITR)

Para restaurar el estado exacto de la base de datos hasta un segundo antes de que ocurriera un incidente no deseado (ejemplo: `2026-11-17 18:30:00`):

1. Restaurar el `basebackup` físico como se indicó en el punto 4.4.
2. Crear un archivo `recovery.signal` en el directorio de datos:
   ```bash
   touch /var/lib/postgresql/data/recovery.signal
   ```
3. Agregar al archivo `postgresql.conf` los parámetros de destino:
   ```ini
   restore_command = 'cp /var/backups/postgresql/wal_archive/%f %p'
   recovery_target_time = '2026-11-17 18:30:00-06'
   recovery_target_action = 'promote'
   ```
4. Iniciar PostgreSQL. El motor aplicará secuencialmente los registros WAL archivados y se detendrá en la marca de tiempo definida, promoviendo el clúster a modo lectura y escritura automáticamente.

---

## 5. Automatización de Tareas Programadas

### 5.1. Programación en Linux / LXC-03 con `crontab` y `pwsh`

Para ejecutar el respaldo completo todos los días a las **02:00 AM** con retención de 7 días:

```bash
# Editar crontab del usuario operador o dba:
crontab -e

# Añadir la siguiente línea:
0 2 * * * pwsh -File /home/manager-dev/digital-brain/02_ues/ADB/encomiendas-envio-seguro/backup/backup_completo.ps1 -RetentionDays 7 >> /home/manager-dev/digital-brain/02_ues/ADB/encomiendas-envio-seguro/backup/logs/cron_backup.log 2>&1
```

### 5.2. Programación en Windows con el Programador de Tareas (Task Scheduler)

Para entornos Windows de los compañeros de equipo:

1. Abrir **Programador de tareas** (`taskschd.msc`).
2. Crear tarea básica:
   * **Nombre:** `ADB_Backup_EnvioSeguro`
   * **Desencadenador:** Diariamente a las `02:00 AM`.
   * **Acción:** Iniciar un programa.
   * **Programa o script:** `powershell.exe`
   * **Agregar argumentos:**  
     `-ExecutionPolicy Bypass -File "C:\ruta\al\proyecto\backup\backup_completo.ps1" -RetentionDays 7`
   * **Iniciar en:** `C:\ruta\al\proyecto\backup\`

---

## 6. Auditoría y Trazabilidad

Cada ejecución del orquestador registra una entrada delimitada por plecas (`|`) en `logs/backup_history.log`:

```text
2026-11-17 02:00:05 | GLOBALES | SUCCESS | 0.05MB | 1.12s | storage/globales/globales_20261117_020005.sql | 
2026-11-17 02:00:08 | LOGICO   | SUCCESS | 1.42MB | 2.85s | storage/logico/envio_seguro_logico_20261117_020008.dump | 
2026-11-17 02:00:15 | FISICO   | SUCCESS | 28.5MB | 6.40s | storage/fisico/basebackup_20261117_020015 | 
```

Esto permite auditar fácilmente los tiempos de ventana de respaldo (RTO), los tamaños históricos de los artefactos y cualquier fallo de conectividad.
