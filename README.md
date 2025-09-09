# PostgreSQL with Polish Language Support

A containerized PostgreSQL database with Polish text search capabilities, pgvector extension for embeddings, and LangChain integration.

## Features

- PostgreSQL 15 with Polish language text search configuration
- pgvector extension for vector embeddings (v0.5.1)
- Polish dictionary from sjp.pl with proper encoding conversion
- LangChain-compatible embedding table structure
- Sample Polish text data for testing
- Automated CI/CD with GitHub Actions

## Getting Started

### Prerequisites

- Docker
- Docker Compose

### Quick Start

1. Clone the repository
2. Start the database:

```bash
docker-compose up --build
```

The database will be available on `localhost:5432` with:
- Database: `postgres`
- Username: `postgres` 
- Password: `postgres`

### Custom Backup

To use your own backup file, uncomment the volume mount in `docker-compose.yml` and place your `backup.sql` file in the project root:

```yaml
- ./backup.sql:/opt/backup/backup.sql:ro
```

## Polish Language Support

The container automatically sets up Polish text search capabilities:

- Downloads and installs Polish dictionary from sjp.pl
- Converts encodings from ISO-8859-2 to UTF-8
- Creates `pl_ispell` text search configuration
- Includes Polish stopwords

### Testing Polish Text Search

Connect to the database and test:

```sql
SELECT to_tsvector('pl_ispell', 'Czuję się mniej więcej tak, jak ktoś, kto bujał w obłokach i nagle spadł.');
```

## Vector Embeddings

The database includes pgvector extension and a LangChain-compatible table:

```sql
-- Table structure
CREATE TABLE langchain_pg_embedding (
    id SERIAL PRIMARY KEY,
    collection_id UUID NOT NULL,
    embedding VECTOR(1536),
    document TEXT,
    cmetadata JSONB
);
```

Sample Polish documents are pre-loaded for testing embeddings and text search.

## Development

### Database Connection

```
Host: localhost
Port: 5432
Database: postgres
Username: postgres
Password: postgres
```

### Health Check

The container includes a health check that verifies PostgreSQL readiness:

```bash
docker-compose ps
```

## CI/CD

Automated Docker image builds are configured for:
- Push to main/master branches
- Pull requests
- Manual workflow dispatch

Images are pushed to GitHub Container Registry at `ghcr.io/[username]/[repository]`.

## Files Overview

- `Dockerfile` - PostgreSQL container with Polish support and pgvector
- `docker-compose.yml` - Service orchestration
- `setup-polish.sh` - Polish language configuration script
- `backup.sql` - Sample data with Polish text and LangChain table
- `.github/workflows/build-and-push.yml` - CI/CD pipeline
