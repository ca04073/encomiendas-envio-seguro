<#
.SYNOPSIS
    Genera un respaldo físico del clúster PostgreSQL usando pg_basebackup.
.DESCRIPTION
    Ejecuta pg_basebackup con formato tar comprimido (-Ft -z) y streaming
    continuo de registros WAL (-X stream). Genera los archivos base.tar.gz y
    pg_wal.tar.gz para recuperación completa del sistema o aprovisionamiento de réplicas.
.PARAMETER PgHost
    Dirección IP o hostname del servidor primario. Por defecto $env:PGHOST o 'localhost'.
.PARAMETER PgPort
    Puerto de conexión de replicación. Por defecto $env:PGPORT o '5432'.
.PARAMETER PgUser
    Usuario con permisos de REPLICATION. Por defecto 'replicator'.
.PARAMETER BackupDir
    Directorio base donde se creará la carpeta con fecha del respaldo físico.
.EXAMPLE
    ./backup_fisico.ps1 -PgHost "192.168.1.100" -PgUser "replicator"
#>

[CmdletBinding()]
param(
    [string]$PgHost = $(if ($env:PGHOST) { $env:PGHOST } else { "localhost" }),
    [int]$PgPort = $(if ($env:PGPORT) { [int]$env:PGPORT } else { 5432 }),
    [string]$PgUser = $(if ($env:PGUSER_REPL) { $env:PGUSER_REPL } else { "replicator" }),
    [string]$BackupDir = $(Join-Path $PSScriptRoot "storage/fisico")
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

# 1. Preparar directorio específico por ejecución
$timestampStr = (Get-Date).ToString("yyyyMMdd_HHmmss")
$targetFolder = Join-Path $BackupDir "basebackup_${timestampStr}"

if (-not (Test-Path $targetFolder)) {
    New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null
    Write-Log "Directorio de respaldo físico creado: $targetFolder"
}

Write-Log "Iniciando respaldo físico (pg_basebackup) desde ${PgHost}:${PgPort}..."
Write-Log "Usuario de replicación: $PgUser"
Write-Log "Modo: Tar Comprimido (-Ft -z) con WAL en Streaming (-X stream)"

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$pgBaseBackupCmd = Get-Command "pg_basebackup" -ErrorAction SilentlyContinue

try {
    if ($pgBaseBackupCmd) {
        & pg_basebackup -h $PgHost -p $PgPort -U $PgUser -D $targetFolder -F t -z -X stream -P -v
    } else {
        Write-Log "pg_basebackup local no encontrado; ejecutando vía contenedor 'pg-primary'..." "WARN"
        $containerBackupPath = "/tmp/basebackup_${timestampStr}"
        & docker exec -e PGPASSWORD=$env:PGPASSWORD_REPL pg-primary pg_basebackup -U $PgUser -D $containerBackupPath -F t -z -X stream -P
        if ($LASTEXITCODE -ne 0) { throw "Error al ejecutar pg_basebackup dentro del contenedor." }
        & docker cp "pg-primary:${containerBackupPath}/." $targetFolder
        & docker exec pg-primary rm -rf $containerBackupPath
    }

    if ($LASTEXITCODE -ne 0) {
        throw "pg_basebackup finalizó con código de error $LASTEXITCODE"
    }

    $stopwatch.Stop()

    # Calcular tamaño acumulado de los archivos tar.gz generados
    $files = Get-ChildItem -Path $targetFolder -File
    $totalBytes = ($files | Measure-Object -Property Length -Sum).Sum
    $sizeMB = [math]::Round($totalBytes / 1MB, 2)
    $duration = [math]::Round($stopwatch.Elapsed.TotalSeconds, 2)

    Write-Log "Respaldo físico completado con éxito en $targetFolder ($sizeMB MB en $duration s)" "OK"

    [PSCustomObject]@{
        Status    = "SUCCESS"
        Type      = "FISICO"
        Folder    = $targetFolder
        Files     = ($files.Name -join ", ")
        SizeMB    = $sizeMB
        DurationS = $duration
        Timestamp = (Get-Date).ToString("o")
    }
}
catch {
    $stopwatch.Stop()
    Write-Log "Error durante el respaldo físico: $_" "ERROR"
    if (Test-Path $targetFolder) {
        Remove-Item $targetFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
    [PSCustomObject]@{
        Status    = "FAILED"
        Type      = "FISICO"
        Folder    = $targetFolder
        Error     = $_.Exception.Message
        DurationS = [math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
        Timestamp = (Get-Date).ToString("o")
    }
    exit 1
}
