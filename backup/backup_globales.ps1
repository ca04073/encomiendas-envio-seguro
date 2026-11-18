<#
.SYNOPSIS
    Genera un respaldo de los objetos globales del clúster PostgreSQL.
.DESCRIPTION
    Ejecuta pg_dumpall con la opción --globals-only para respaldar roles,
    cuentas de usuario, contraseñas encriptadas (scram-sha-256), tablespaces y
    permisos a nivel de servidor que no son incluidos por pg_dump de base individual.
.PARAMETER PgHost
    Dirección IP o hostname del servidor PostgreSQL.
.PARAMETER PgPort
    Puerto del servidor PostgreSQL.
.PARAMETER PgUser
    Usuario administrador del clúster (superusuario o equivalente).
.PARAMETER BackupDir
    Directorio de destino para almacenar el archivo .sql.
.EXAMPLE
    ./backup_globales.ps1 -PgHost "localhost" -PgUser "postgres"
#>

[CmdletBinding()]
param(
    [string]$PgHost = $(if ($env:PGHOST) { $env:PGHOST } else { "localhost" }),
    [int]$PgPort = $(if ($env:PGPORT) { [int]$env:PGPORT } else { 5432 }),
    [string]$PgUser = $(if ($env:PGUSER) { $env:PGUSER } else { "postgres" }),
    [string]$BackupDir = $(Join-Path $PSScriptRoot "storage/globales")
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

# 2. Definir nombre de archivo
$timestampStr = (Get-Date).ToString("yyyyMMdd_HHmmss")
$filename = "globales_${timestampStr}.sql"
$destinationFile = Join-Path $BackupDir $filename

Write-Log "Iniciando respaldo de objetos globales (roles, tablespaces)..."
Write-Log "Destino: $destinationFile"

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$pgDumpallCmd = Get-Command "pg_dumpall" -ErrorAction SilentlyContinue

try {
    if ($pgDumpallCmd) {
        & pg_dumpall -h $PgHost -p $PgPort -U $PgUser --globals-only -f $destinationFile -v
    } else {
        Write-Log "pg_dumpall local no encontrado; ejecutando vía contenedor 'pg-primary'..." "WARN"
        $containerBackupPath = "/tmp/$filename"
        & docker exec -e PGPASSWORD=$env:PGPASSWORD pg-primary pg_dumpall -U $PgUser --globals-only -f $containerBackupPath
        if ($LASTEXITCODE -ne 0) { throw "Error al ejecutar pg_dumpall dentro del contenedor." }
        & docker cp "pg-primary:${containerBackupPath}" $destinationFile
        & docker exec pg-primary rm -f $containerBackupPath
    }

    if ($LASTEXITCODE -ne 0) {
        throw "pg_dumpall finalizó con código de error $LASTEXITCODE"
    }

    $stopwatch.Stop()
    $fileInfo = Get-Item $destinationFile
    $sizeKB = [math]::Round($fileInfo.Length / 1KB, 2)
    $duration = [math]::Round($stopwatch.Elapsed.TotalSeconds, 2)

    Write-Log "Respaldo de globales completado con éxito: $filename ($sizeKB KB en $duration s)" "OK"

    [PSCustomObject]@{
        Status    = "SUCCESS"
        Type      = "GLOBALES"
        File      = $destinationFile
        SizeKB    = $sizeKB
        DurationS = $duration
        Timestamp = (Get-Date).ToString("o")
    }
}
catch {
    $stopwatch.Stop()
    Write-Log "Error durante el respaldo de globales: $_" "ERROR"
    if (Test-Path $destinationFile) {
        Remove-Item $destinationFile -Force -ErrorAction SilentlyContinue
    }
    [PSCustomObject]@{
        Status    = "FAILED"
        Type      = "GLOBALES"
        File      = $destinationFile
        Error     = $_.Exception.Message
        DurationS = [math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
        Timestamp = (Get-Date).ToString("o")
    }
    exit 1
}
