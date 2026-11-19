FROM postgres:17-alpine

ARG PGAUDIT_VERSION=17.0

RUN apk add --no-cache --virtual .build-deps \
    build-base \
    git \
  && git clone --depth 1 \
    --branch REL_17_STABLE \
    https://github.com/pgaudit/pgaudit.git /tmp/pgaudit \
  && cd /tmp/pgaudit \
  && make USE_PGXS=1 \
  && make USE_PGXS=1 install \
  && cd / \
  && rm -rf /tmp/pgaudit \
  && apk del .build-deps \
  && test -f "$(pg_config --pkglibdir)/pgaudit.so" \
  && test -f "$(pg_config --sharedir)/extension/pgaudit.control"
