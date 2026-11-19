FROM postgres:17-alpine

# Instalar dependencias de compilación para PGXS y pgAudit en Alpine
RUN apk add --no-cache --virtual .pgaudit-build-deps \
    git \
    make \
    gcc \
    libc-dev \
    krb5-dev \
    postgresql17-dev \
  && git clone --depth 1 --branch REL_17_STABLE https://github.com/pgaudit/pgaudit.git /tmp/pgaudit \
  && cd /tmp/pgaudit \
  && make USE_PGXS=1 \
  && make USE_PGXS=1 install \
  && cd / \
  && rm -rf /tmp/pgaudit \
  && apk del .pgaudit-build-deps
