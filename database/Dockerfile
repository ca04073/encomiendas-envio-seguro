# =====================================================================
# PostgreSQL 17 con extensión pgAudit (Compilación nativa en Alpine)
# =====================================================================

# --- Etapa 1: Compilador temporal ---
FROM postgres:17-alpine AS builder

RUN apk add --no-cache --virtual .build-deps \
    build-base \
    git \
    postgresql-dev \
    krb5-dev \
  && git clone --depth 1 --branch REL_17_STABLE https://github.com/pgaudit/pgaudit.git /tmp/pgaudit \
  && cd /tmp/pgaudit \
  && make USE_PGXS=1 with_llvm=no install

# --- Etapa 2: Imagen limpia de producción ---
FROM postgres:17-alpine

# Copiar la librería compilada y los archivos de control de la extensión
COPY --from=builder /usr/local/lib/postgresql/pgaudit.so /usr/local/lib/postgresql/
COPY --from=builder /usr/local/share/postgresql/extension/pgaudit* /usr/local/share/postgresql/extension/
