\set ON_ERROR_STOP on

/*
===============================================================================
PROYECTO: ENVIO SEGURO
ARCHIVO: 00_verificar_entorno.sql
PROPÃ“SITO:
    Verificar que la sesión psql está conectada a la instancia, puerto y base
    de datos esperados antes de ejecutar cambios de seguridad.

ENTORNO OBJETIVO:
    PostgreSQL 17 | Windows | localhost:5437 | envio_seguro

EJECUCIÃ“N:
    psql -h localhost -p 5437 -U postgres -d envio_seguro `
         -v ON_ERROR_STOP=1 -f .\\scripts\\00_verificar_entorno.sql

EFECTOS:
    Solo lectura. No modifica objetos ni privilegios.
===============================================================================
*/

\echo '--- Verificacion del entorno Envio Seguro ---'

SELECT
    current_database()                  AS base_de_datos,
    current_user                        AS usuario_actual,
    session_user                        AS usuario_de_sesion,
    inet_server_addr()                  AS direccion_servidor,
    inet_server_port()                  AS puerto_servidor,
    current_setting('server_version')   AS version_servidor,
    current_setting('server_version_num') AS version_num;

\echo '--- Comprobacion de parametros esperados ---'

SELECT
    current_database() = 'envio_seguro' AS base_correcta,
    inet_server_port() = 5437           AS puerto_correcto,
    current_setting('server_version_num')::integer / 10000 = 17
                                         AS version_17;
