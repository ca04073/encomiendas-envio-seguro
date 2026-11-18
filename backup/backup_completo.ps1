<#
.SYNOPSIS
    Orquestador maestro de respaldos con auditoría y política de retención.
.DESCRIPTION
    Ejecuta en secuencia la estrategia integral de respaldos:
      1. Objetos globales del clúster (roles y credenciales).
      2. Respaldo lógico comprimido de la base 'envio_seguro'.
      3. Respaldo físico del clúster (basebackup + WAL streaming).
    Registra el resultado en 'logs/backup_history.log' y purga respaldos
    antiguos según los días de retención especificados (por defecto 7 días).
.PARAMETER RetentionDays
    Cantidad de días para conservar respaldos antes de su purga automática.
.PARAMETER SkipPhysical
    Indica si se omite el respaldo físico (útil para rutinas rápidas o por cuota).
.PARAMETER PgHost
    Dirección IP o hostname del nodo primario de PostgreSQL.
.EXAMPLE
    ./backup_completo.ps1 -RetentionDays 7
#>

[CmdletBinding()]
param(
    [int]$RetentionDays = 7,
    [switch]$SkipPhysical,
    [string]$PgHost = $(if ($env:PGHOST) { $env:PGHOST } else { "localhost" }),
    [int]$PgPort = $(if ($env:PGPORT) { [int]$env:PGPORT } else { 5432 }),
    [string]$PgUser = $(if ($env:PGUSER) { $env:PGUSER } else { "postgres" }),
    [string]$PgDatabase = $(if ($env:PGDATABASE) { $env:PGDATABASE } else { "envio_seguro" })
)

$ErrorActionPreference = "Continue"

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

# 1. Directorios base
$baseDir = $PSScriptRoot
$logDir = Join-Path $baseDir "logs"
$historyLog = Join-Path $logDir "backup_history.log"

if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

function Audit-Log {
    param($Entry)
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $line = "$timestamp | $($Entry.Type) | $($Entry.Status) | $($Entry.SizeMB)MB | $($Entry.DurationS)s | $($Entry.File)$($Entry.Folder) | $($Entry.Error)"
    Add-Content -Path $historyLog -Value $line
}

Write-Host "========================================================================" -ForegroundColor Magenta
Write-Host "  🛡️  ENVÍO SEGURO - ORQUESTADOR MAESTRO DE RESPALDOS POSTGRESQL       " -ForegroundColor Magenta
Write-Host "========================================================================" -ForegroundColor Magenta
Write-Log "Iniciando ciclo completo de respaldos contra host '$PgHost'..."

$results = [System.Collections.Generic.List[PSObject]]::new()
$globalStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# -----------------------------------------------------------------------------
# FASE 1: Respaldo de Globales
# -----------------------------------------------------------------------------
Write-Host "`n--- [1/3] RESPALDO DE OBJETOS GLOBALES (ROLES & SISTEMA) ---" -ForegroundColor Yellow
$scriptGlobales = Join-Path $baseDir "backup_globales.ps1"
if (Test-Path $scriptGlobales) {
    $resGlobales = & $scriptGlobales -PgHost $PgHost -PgPort $PgPort -PgUser $PgUser
    $results.Add($resGlobales)
    Audit-Log $resGlobales
} else {
    Write-Log "Script $scriptGlobales no encontrado." "ERROR"
}

# -----------------------------------------------------------------------------
# FASE 2: Respaldo Lógico de Base de Datos
# -----------------------------------------------------------------------------
Write-Host "`n--- [2/3] RESPALDO LÓGICO COMPRIMIDO (BASE 'envio_seguro') ---" -ForegroundColor Yellow
$scriptLogico = Join-Path $baseDir "backup_logico.ps1"
if (Test-Path $scriptLogico) {
    $resLogico = & $scriptLogico -PgHost $PgHost -PgPort $PgPort -PgUser $PgUser -PgDatabase $PgDatabase
    $results.Add($resLogico)
    Audit-Log $resLogico
} else {
    Write-Log "Script $scriptLogico no encontrado." "ERROR"
}

# -----------------------------------------------------------------------------
# FASE 3: Respaldo Físico (Clúster + WAL)
# -----------------------------------------------------------------------------
if (-not $SkipPhysical) {
    Write-Host "`n--- [3/3] RESPALDO FÍSICO Y WAL STREAMING (CLÚSTER) ---" -ForegroundColor Yellow
    $scriptFisico = Join-Path $baseDir "backup_fisico.ps1"
    if (Test-Path $scriptFisico) {
        $resFisico = & $scriptFisico -PgHost $PgHost -PgPort $PgPort
        $results.Add($resFisico)
        Audit-Log $resFisico
    } else {
        Write-Log "Script $scriptFisico no encontrado." "ERROR"
    }
} else {
    Write-Log "Fase de respaldo físico omitida por parámetro (-SkipPhysical)." "WARN"
}

# -----------------------------------------------------------------------------
# FASE 4: Política de Retención y Purga Automática
# -----------------------------------------------------------------------------
Write-Host "`n--- [MANTENIMIENTO] POLÍTICA DE RETENCIÓN ($RetentionDays DÍAS) ---" -ForegroundColor Yellow
$cutoffDate = (Get-Date).AddDays(-$RetentionDays)
Write-Log "Buscando artefactos anteriores a: $($cutoffDate.ToString('yyyy-MM-dd HH:mm:ss'))"

$storageDir = Join-Path $baseDir "storage"
$purgedCount = 0

if (Test-Path $storageDir) {
    # Purga de archivos .dump y .sql (Lógico y Globales)
    $oldFiles = Get-ChildItem -Path $storageDir -Recurse -File | Where-Object { $_.LastWriteTime -lt $cutoffDate }
    foreach ($file in $oldFiles) {
        Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
        Write-Log "Archivo purgado por antigüedad: $($file.Name)" "WARN"
        $purgedCount++
    }

    # Purga de carpetas de respaldo físico basebackup_*
    $oldFolders = Get-ChildItem -Path (Join-Path $storageDir "fisico") -Directory -ErrorAction SilentlyContinue | 
                  Where-Object { $_.LastWriteTime -lt $cutoffDate }
    foreach ($folder in $oldFolders) {
        Remove-Item -Path $folder.FullName -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log "Directorio físico purgado por antigüedad: $($folder.Name)" "WARN"
        $purgedCount++
    }
}
Write-Log "Purga finalizada. Elementos eliminados: $purgedCount" "OK"

# -----------------------------------------------------------------------------
# RESUMEN EJECUTIVO FINAL
# -----------------------------------------------------------------------------
$globalStopwatch.Stop()
$totalSeconds = [math]::Round($globalStopwatch.Elapsed.TotalSeconds, 2)

Write-Host "`n========================================================================" -ForegroundColor Green
Write-Host "  📊 RESUMEN DE EJECUCIÓN - CICLO DE RESPALDO (Duración: ${totalSeconds}s)" -ForegroundColor Green
Write-Host "========================================================================" -ForegroundColor Green

$results | Format-Table -Property Type, Status, SizeMB, DurationS, Timestamp -AutoSize

$failedCount = ($results | Where-Object { $_.Status -ne "SUCCESS" }).Count
if ($failedCount -gt 0) {
    Write-Log "ALERTA: Se detectaron $failedCount fallo(s) durante el ciclo de respaldo. Revise $historyLog" "ERROR"
    exit 1
} else {
    Write-Log "Ciclo de respaldos completado exitosamente sin errores." "OK"
    exit 0
}
