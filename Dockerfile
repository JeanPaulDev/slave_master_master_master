# Dockerfile
# Base: Imagen oficial de Debian con las herramientas básicas
FROM debian:bookworm-slim

# Paso 1: Instalar herramientas base y MariaDB client
# Nota: La primera apt-get update solo ve los repositorios de Debian
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    mariadb-client \
    ca-certificates \
    gnupg

# Paso 2: Añadir repositorio de Docker e instalar Docker CLI
# Se requiere una segunda apt-get update para ver el nuevo repositorio
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    echo \
    "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
    "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    # Usamos docker-ce-cli para la versión enterprise client, la más segura.
    apt-get install -y docker-ce-cli

# Paso 3: Limpiar caché
RUN apt-get clean && rm -rf /var/lib/apt/lists/*