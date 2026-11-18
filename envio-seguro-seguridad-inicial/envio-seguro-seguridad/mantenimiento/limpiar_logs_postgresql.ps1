# ==========================================
# ENVIO-SEGURO
# Retencion de logs PostgreSQL
# Politica: 30 dias
# PowerShell 5.1
# ==========================================

$ErrorActionPreference = "Stop"

$RutaLogs = "C:\Program Files\PostgreSQL\17\data\log"
$Psql = "C:\Program Files\PostgreSQL\17\bin\psql.exe"

$DiasRetencion = 30
$FechaLimite = (Get-Date).AddDays(-$DiasRetencion)

$EjecutarEliminacion = $false

$RutaHistorial = Join-Path $PSScriptRoot "historial_limpieza.log"

function Escribir-Historial {
    param([string]$Mensaje)

    $Fecha = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -LiteralPath $RutaHistorial `
        -Value "[$Fecha] $Mensaje" -Encoding UTF8

    Write-Output $Mensaje
}

# 1. Verificar directorio
if (-not (Test-Path -LiteralPath $RutaLogs -PathType Container)) {
    Escribir-Historial "ERROR: Log directory does not exist."
    exit 1
}

# 2. Verificar psql
if (-not (Test-Path -LiteralPath $Psql -PathType Leaf)) {
    Escribir-Historial "ERROR: psql.exe was not found."
    exit 1
}

# 3. Obtener log actual
$LogActual = & $Psql -X -h localhost -p 5437 `
    -U postgres -d envio_seguro -t -A `
    -c "SELECT pg_current_logfile();"

if ($LASTEXITCODE -ne 0) {
    Escribir-Historial "ERROR: Could not identify current PostgreSQL log."
    exit 1
}

$LogActual = ($LogActual | Out-String).Trim()

if ([string]::IsNullOrWhiteSpace($LogActual)) {
    Escribir-Historial "ERROR: Empty PostgreSQL log path."
    exit 1
}

$NombreLogActual = Split-Path $LogActual -Leaf

Escribir-Historial "Cleanup started. Mode: SIMULATION."
Escribir-Historial "Current log: $NombreLogActual"

# 4. Buscar archivos antiguos
$ArchivosAntiguos = @(
    Get-ChildItem -LiteralPath $RutaLogs `
        -Filter "postgresql-*.log" -File |
    Where-Object {
        $_.LastWriteTime -lt $FechaLimite -and
        $_.Name -ne $NombreLogActual
    }
)

# 5. Procesar resultados
if ($ArchivosAntiguos.Count -eq 0) {
    Escribir-Historial "No old logs found."
}
else {
    foreach ($Archivo in $ArchivosAntiguos) {

        if ($EjecutarEliminacion) {
            Remove-Item -LiteralPath $Archivo.FullName -Force
            Escribir-Historial "Deleted: $($Archivo.Name)"
        }
        else {
            Escribir-Historial "SIMULATION: Would delete $($Archivo.Name)"
        }
    }
}

Escribir-Historial "Cleanup finished."