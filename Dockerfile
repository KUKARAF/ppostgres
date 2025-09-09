FROM postgres:15

# Install required packages including build tools for pgvector
RUN apt-get update && apt-get install -y \
    wget \
    bzip2 \
    postgresql-contrib \
    build-essential \
    git \
    postgresql-server-dev-all \
    && rm -rf /var/lib/apt/lists/*

# Install pgvector extension
RUN cd /tmp && \
    git clone --branch v0.5.1 https://github.com/pgvector/pgvector.git && \
    cd pgvector && \
    make && \
    make install && \
    cd / && \
    rm -rf /tmp/pgvector

# Create a directory for optional backup mounting
RUN mkdir -p /opt/backup

# Copy default backup file (can be overridden by volume mount)
COPY backup.sql /opt/backup/backup.sql

# Create a script to install extensions first (runs before backup)
RUN echo '#!/bin/bash' > /docker-entrypoint-initdb.d/00-setup-extensions.sh && \
    echo 'echo "Setting up extensions..."' >> /docker-entrypoint-initdb.d/00-setup-extensions.sh && \
    echo 'psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL' >> /docker-entrypoint-initdb.d/00-setup-extensions.sh && \
    echo '    CREATE EXTENSION IF NOT EXISTS vector;' >> /docker-entrypoint-initdb.d/00-setup-extensions.sh && \
    echo 'EOSQL' >> /docker-entrypoint-initdb.d/00-setup-extensions.sh && \
    chmod +x /docker-entrypoint-initdb.d/00-setup-extensions.sh

# Create a script to conditionally load backup (runs after extensions)
RUN echo '#!/bin/bash' > /docker-entrypoint-initdb.d/01-load-backup.sh && \
    echo 'if [ -f /opt/backup/backup.sql ]; then' >> /docker-entrypoint-initdb.d/01-load-backup.sh && \
    echo '  echo "Loading backup from /opt/backup/backup.sql"' >> /docker-entrypoint-initdb.d/01-load-backup.sh && \
    echo '  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -f /opt/backup/backup.sql' >> /docker-entrypoint-initdb.d/01-load-backup.sh && \
    echo 'else' >> /docker-entrypoint-initdb.d/01-load-backup.sh && \
    echo '  echo "No backup file found at /opt/backup/backup.sql"' >> /docker-entrypoint-initdb.sh && \
    echo 'fi' >> /docker-entrypoint-initdb.d/01-load-backup.sh && \
    chmod +x /docker-entrypoint-initdb.d/01-load-backup.sh

# Copy the setup script (runs after backup)
COPY setup-polish.sh /docker-entrypoint-initdb.d/02-setup-polish.sh

# Make the script executable
RUN chmod +x /docker-entrypoint-initdb.d/02-setup-polish.sh

# Set environment variables
ENV POSTGRES_DB=postgres
ENV POSTGRES_USER=postgres
ENV POSTGRES_PASSWORD=postgres
