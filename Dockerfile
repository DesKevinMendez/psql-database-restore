FROM postgres:17

# Crear directorio para el dump
RUN mkdir /dumps
WORKDIR /dumps

# Copiar el script de inicialización
COPY init.sh /docker-entrypoint-initdb.d/ 