/*
=========================================================
PROYECTO: ENVÍO-SEGURO
SCRIPT: 09_configurar_pgaudit.sql
DESCRIPCIÓN: Configuración de auditoría mediante pgAudit
REQUISITO: PostgreSQL 17 y pgAudit 17.x
EJECUTAR COMO: postgres (superusuario)
=========================================================

IMPORTANTE:
1. pgAudit debe estar instalado en el servidor.
2. Debe agregarse a shared_preload_libraries.
3. El servidor debe reiniciarse después de modificar
   shared_preload_libraries.
4. CREATE EXTENSION se aplica a la base conectada.
5. ALTER SYSTEM configura la instancia PostgreSQL completa,
   no solamente esta base de datos.
*/

-- 1. Crear la extensión en la base de datos.
CREATE EXTENSION IF NOT EXISTS pgaudit;

-- 2. Configurar las categorías de auditoría para la instancia.
--    Revisar el impacto si el servidor aloja otras bases de datos.
ALTER SYSTEM SET pgaudit.log = 'READ, WRITE, DDL, ROLE';

-- 3. Recargar la configuración.
SELECT pg_reload_conf();

-- 4. Verificar la extensión instalada.
SELECT
    extname,
    extversion
FROM pg_extension
WHERE extname = 'pgaudit';

-- 5. Verificar la configuración de auditoría.
SHOW pgaudit.log;

-- 6. Verificar que PostgreSQL cargó pgAudit.
SHOW shared_preload_libraries;





