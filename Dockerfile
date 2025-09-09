FROM postgres:15

# Install required packages including build tools for pgvector
RUN apt-get update && apt-get install -y \
    wget \
    bzip2 \
    postgresql-contrib \
    build-essential \
    git \
    postgresql-server-dev-15 \
    && rm -rf /var/lib/apt/lists/*

# Install pgvector extension
RUN cd /tmp && \
    git clone --branch v0.5.1 https://github.com/pgvector/pgvector.git && \
    cd pgvector && \
    make && \
    make install && \
    cd / && \
    rm -rf /tmp/pgvector

# Copy the backup file
COPY backup.sql /docker-entrypoint-initdb.d/01-backup.sql

# Copy the setup script
COPY setup-polish.sh /docker-entrypoint-initdb.d/02-setup-polish.sh

# Make the script executable
RUN chmod +x /docker-entrypoint-initdb.d/02-setup-polish.sh

# Set environment variables
ENV POSTGRES_DB=postgres
ENV POSTGRES_USER=postgres
ENV POSTGRES_PASSWORD=postgres
