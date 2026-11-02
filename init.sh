#!/usr/bin/env bash
# ====================================================================
# 🚀 TEMPLATE INITIALIZATION SCRIPT (init.sh)
# Propósito: Sustituir variables, activar Git hooks y preparar el repo
# ====================================================================

set -e

# Colores para salida interactiva
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}${BOLD}=====================================================${NC}"
echo -e "${BLUE}${BOLD}   🚀 INICIALIZADOR DE PROYECTO BASE (TEMPLATE)     ${NC}"
echo -e "${BLUE}${BOLD}=====================================================${NC}\n"

# 1. Recolección interactiva de parámetros
read -rp "Nombre del Proyecto (ej. auth-service): " PROJECT_NAME
read -rp "Breve descripcion del proyecto: " PROJECT_DESCRIPTION
read -rp "GitHub Owner (usuario u org, sin @): " GITHUB_OWNER
read -rp "Puerto del Contenedor (ej. 8080): " CONTAINER_PORT
read -rp "Puerto del Host Local (ej. 8080): " HOST_PORT

# Validar que no haya campos vacíos esenciales
if [[ -z "$PROJECT_NAME" || -z "$GITHUB_OWNER" ]]; then
  echo -e "\n${RED}ERROR: El nombre del proyecto y el GitHub Owner son obligatorios.${NC}"
  exit 1
fi

CONTAINER_PORT=${CONTAINER_PORT:-8080}
HOST_PORT=${HOST_PORT:-8080}

echo -e "\n${YELLOW}Aplicando reemplazo de variables...${NC}"

# Detectar flag compatible con sed de GNU (Linux) o BSD (macOS)
sedi() {
  if sed --version >/dev/null 2>&1; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}

# Lista de archivos a procesar
TARGET_FILES=(
  "README.md"
  "compose.yaml"
  "Dockerfile"
  ".github/CODEOWNERS"
  ".devcontainer/devcontainer.json"
)

# Sustitución de marcadores en archivos existentes
for file in "${TARGET_FILES[@]}"; do
  if [ -f "$file" ]; then
    # Marcadores estándar
    sedi "s|{{PROJECT_NAME}}|$PROJECT_NAME|g" "$file"
    sedi "s|{{PROJECT_DESCRIPTION}}|$PROJECT_DESCRIPTION|g" "$file"
    sedi "s|{{GITHUB_OWNER}}|$GITHUB_OWNER|g" "$file"
    sedi "s|{{CONTAINER_PORT}}|$CONTAINER_PORT|g" "$file"
    sedi "s|{{HOST_PORT}}|$HOST_PORT|g" "$file"

    # Reemplazo seguro para ARG CONTAINER_PORT=<valor> en Dockerfile
    if [[ "$file" == "Dockerfile" || "$file" == "Containerfile" ]]; then
      sedi -E "s|ARG CONTAINER_PORT=[0-9]+|ARG CONTAINER_PORT=${CONTAINER_PORT}|g" "$file"
    fi

    echo -e "  ${GREEN}✓${NC} $file actualizado"
  fi
done

# Preparar archivo .env si no existe
if [ ! -f .env ] && [ -f .env.example ]; then
  cp .env.example .env
  echo -e "  ${GREEN}✓${NC} Archivo .env generado a partir de .env.example"
fi

# 2. Configurar Git Hooks
echo -e "\n${YELLOW}Configurando Git Hooks...${NC}"

if [ -d ".githooks" ]; then
  chmod +x .githooks/* || true
  git config core.hooksPath .githooks
  echo -e "  ${GREEN}✓${NC} Permisos de ejecución otorgados a .githooks/"
  echo -e "  ${GREEN}✓${NC} core.hooksPath configurado en .githooks"
else
  echo -e "  ${YELLOW}Directorio .githooks no encontrado; se omitió la vinculación.${NC}"
fi

# 3. Limpieza de archivos de andamiaje (scaffolding)
if [ -f "SETUP.md" ]; then
  rm -f SETUP.md
  echo -e "  ${GREEN}✓${NC} SETUP.md eliminado (documentación operativa consolidada en README.md)"
fi

# 4. Mensaje de cierre e instrucciones de protección
echo -e "\n${BLUE}${BOLD}=====================================================${NC}"
echo -e "${GREEN}${BOLD}   ✅ INICIALIZACIÓN COMPLETADA CON ÉXITO           ${NC}"
echo -e "${BLUE}${BOLD}=====================================================${NC}\n"

echo -e "${BOLD}🛡️  Protección de la rama 'main':${NC}"
echo -e "  El ruleset de protección ya está incluido en el repositorio:"
echo -e "  ${YELLOW}.github/rulesets/main-protection.json${NC}\n"
echo -e "  Para activarlo en GitHub:"
echo -e "  1. Ve a ${BOLD}Settings > Rules > Rulesets${NC} en este nuevo repositorio."
echo -e "  2. Haz clic en la flecha de ${BOLD}New ruleset > Import a ruleset${NC}."
echo -e "  3. Selecciona el archivo ${BOLD}.github/rulesets/main-protection.json${NC}."
echo -e "  4. Verifica que el estado sea ${GREEN}Active${NC} y presiona ${BOLD}Save changes${NC}.\n"

echo -e "${BLUE}-----------------------------------------------------${NC}"
rm -- "$0"
echo -e "🗑️  Script init.sh eliminado tras inicialización exitosa.\n"

exit 0
