FROM postgres:15

# Install required packages
RUN apt-get update && apt-get install -y \
    wget \
    bzip2 \
    postgresql-contrib \
    && rm -rf /var/lib/apt/lists/*

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
