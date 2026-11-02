FROM alpine:3.20

# Metadatos del contenedor
LABEL maintainer="manager-dev"
LABEL org.opencontainers.image.description="Baseline container image template"

# Utilidades mínimas esenciales
RUN apk add --no-cache \
    ca-certificates \
    tzdata \
    curl \
    bash

WORKDIR /app

# Puerto expuesto parametrizado
ARG CONTAINER_PORT=8080
EXPOSE ${CONTAINER_PORT}

# Punto de entrada por defecto
CMD ["sh"]
