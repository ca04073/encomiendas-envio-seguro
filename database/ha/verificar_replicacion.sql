-- =====================================================================
-- VERIFICACIÓN INTEGRAL DE ALTA DISPONIBILIDAD Y STREAMING REPLICATION
-- Proyecto: Sistema de Encomiendas "Envío Seguro" (ADB135)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. CONSULTA EN EL NODO PRIMARIO (pg-primary)
-- Debe mostrar el proceso 'walreceiver', usuario 'replicator', estado
-- 'streaming' y el retraso de replicación en bytes (replay_lag_bytes).
-- ---------------------------------------------------------------------
\echo '=== [pg-primary] ESTADO DE REPLICACIÓN EN EL NODO MAESTRO ==='
SELECT 
    pid, 
    usename, 
    application_name, 
    client_addr, 
    state, 
    sync_state, 
    sync_priority,
    sent_lsn,
    write_lsn,
    flush_lsn,
    replay_lsn,
    pg_wal_lsn_diff(sent_lsn, replay_lsn) AS replay_lag_bytes
FROM pg_stat_replication;

-- ---------------------------------------------------------------------
-- 2. CONSULTA EN EL NODO RÉPLICA (pg-standby)
-- 'is_hot_standby' debe retornar 't' (true) en el standby y 'f' en el primario.
-- ---------------------------------------------------------------------
\echo '=== MODO DE RECUPERACIÓN / READ-ONLY ==='
SELECT 
    pg_is_in_recovery() AS is_hot_standby,
    pg_last_wal_receive_lsn() AS last_receive_lsn,
    pg_last_wal_replay_lsn() AS last_replay_lsn,
    pg_last_xact_replay_timestamp() AS last_xact_timestamp;
