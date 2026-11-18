<#
.SYNOPSIS
    Genera un respaldo lógico comprimido (-Fc) de la base de datos PostgreSQL.
.DESCRIPTION
    Ejecuta pg_dump en formato Custom con compresión (-Z 6) para permitir
    restauraciones granulares por tabla o reconstrucción completa vía pg_restore.
    Compatible con Windows PowerShell 5.1+ y PowerShell Core (pwsh) en Linux.
.PARAMETER PgHost
    Dirección IP o hostname del servidor PostgreSQL. Por defecto lee $env:PGHOST o 'localhost'.
.PARAMETER PgPort
    Puerto del servidor PostgreSQL. Por defecto lee $env:PGPORT o '5432'.
.PARAMETER PgUser
    Usuario administrador/DBA para la conexión. Por defecto lee $env:PGUSER o 'postgres'.
.PARAMETER PgDatabase
    Nombre de la base de datos a respaldar. Por defecto 'envio_seguro'.
.PARAMETER BackupDir
    Directorio de destino para almacenar los archivos .dump.
.PARAMETER CompressionLevel
    Nivel de compresión gzip (1-9). Por defecto 6.
.EXAMPLE
    ./backup_logico.ps1 -PgHost "192.168.1.100" -PgUser "postgres"
#>

[CmdletBinding()]
param(
    [string]$PgHost = $(if ($env:PGHOST) { $env:PGHOST } else { "localhost" }),
    [int]$PgPort = $(if ($env:PGPORT) { [int]$env:PGPORT } else { 5432 }),
    [string]$PgUser = $(if ($env:PGUSER) { $env:PGUSER } else { "postgres" }),
    [string]$PgDatabase = $(if ($env:PGDATABASE) { $env:PGDATABASE } else { "envio_seguro" }),
    [string]$BackupDir = $(Join-Path $PSScriptRoot "storage/logico"),
    [int]$CompressionLevel = 6
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN"  { "Yellow" }
        "OK"    { "Green" }
        default { "Cyan" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

# 1. Asegurar directorio de destino
if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    Write-Log "Directorio creado: $BackupDir"
}

# 2. Definir nomenclatura con timestamp
$timestampStr = (Get-Date).ToString("yyyyMMdd_HHmmss")
$filename = "${PgDatabase}_logico_${timestampStr}.dump"
$destinationFile = Join-Path $BackupDir $filename

Write-Log "Iniciando respaldo lógico de '$PgDatabase'..."
Write-Log "Destino: $destinationFile"
Write-Log "Servidor: ${PgHost}:${PgPort} | Usuario: $PgUser"

# 3. Detectar ejecutable pg_dump o fallback Docker
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$pgDumpCmd = Get-Command "pg_dump" -ErrorAction SilentlyContinue

try {
    if ($pgDumpCmd) {
        & pg_dump -h $PgHost -p $PgPort -U $PgUser -d $PgDatabase -F c -Z $CompressionLevel -f $destinationFile -v
    } else {
        # Fallback a docker exec si pg_dump local no está instalado
        Write-Log "pg_dump local no encontrado; intentando vía contenedor Docker 'pg-primary'..." "WARN"
        $containerBackupPath = "/tmp/$filename"
        & docker exec -e PGPASSWORD=$env:PGPASSWORD pg-primary pg_dump -U $PgUser -d $PgDatabase -F c -Z $CompressionLevel -f $containerBackupPath
        if ($LASTEXITCODE -ne 0) { throw "Error al ejecutar pg_dump dentro del contenedor Docker." }
        & docker cp "pg-primary:${containerBackupPath}" $destinationFile
        & docker exec pg-primary rm -f $containerBackupPath
    }

    if ($LASTEXITCODE -ne 0) {
        throw "pg_dump finalizó con código de error $LASTEXITCODE"
    }

    $stopwatch.Stop()
    $fileInfo = Get-Item $destinationFile
    $sizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
    $duration = [math]::Round($stopwatch.Elapsed.TotalSeconds, 2)

    Write-Log "Respaldo lógico completado con éxito: $filename ($sizeMB MB en $duration s)" "OK"
    
    # Retornar objeto con metadatos del respaldo
    [PSCustomObject]@{
        Status    = "SUCCESS"
        Type      = "LOGICO"
        File      = $destinationFile
        SizeMB    = $sizeMB
        DurationS = $duration
        Timestamp = (Get-Date).ToString("o")
    }
}
catch {
    $stopwatch.Stop()
    Write-Log "Error durante el respaldo lógico: $_" "ERROR"
    if (Test-Path $destinationFile) {
        Remove-Item $destinationFile -Force -ErrorAction SilentlyContinue
    }
    [PSCustomObject]@{
        Status    = "FAILED"
        Type      = "LOGICO"
        File      = $destinationFile
        Error     = $_.Exception.Message
        DurationS = [math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
        Timestamp = (Get-Date).ToString("o")
    }
    exit 1
}
