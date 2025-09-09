#!/bin/bash
set -e

# Wait for PostgreSQL to be ready
until pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"; do
  echo "Waiting for PostgreSQL to be ready..."
  sleep 2
done

# Create a temporary directory for downloads
TEMP_DIR="/tmp/polish-setup"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Download the latest Polish dictionary from sjp.pl
echo "Downloading Polish dictionary..."
# Get the latest version (this URL pattern should work for recent versions)
wget -O polish-dict.tar.bz2 "https://sjp.pl/slownik/ort/sjp-ispell-pl-20230101-src.tar.bz2" || \
wget -O polish-dict.tar.bz2 "https://sjp.pl/slownik/ort/sjp-ispell-pl-20220101-src.tar.bz2" || \
wget -O polish-dict.tar.bz2 "https://sjp.pl/slownik/ort/sjp-ispell-pl-20210101-src.tar.bz2"

# Extract the archive
echo "Extracting Polish dictionary..."
tar -xjf polish-dict.tar.bz2
cd sjp-ispell-pl-*

# Download Polish stopwords from GitHub
echo "Downloading Polish stopwords..."
wget -O polish.stopwords.txt "https://raw.githubusercontent.com/bieli/stopwords-pl/master/polish.stopwords.txt"

# Convert encodings to UTF-8 and rename files
echo "Converting encodings..."
iconv -f ISO_8859-2 -t utf-8 polish.aff > polish.affix
iconv -f ISO_8859-2 -t utf-8 polish.all > polish.dict
mv polish.stopwords.txt polish.stop

# Get PostgreSQL share directory
SHARE_DIR=$(pg_config --sharedir)
TSEARCH_DIR="$SHARE_DIR/tsearch_data"

# Copy files to PostgreSQL tsearch_data directory
echo "Copying files to PostgreSQL directory..."
cp polish.affix "$TSEARCH_DIR/"
cp polish.dict "$TSEARCH_DIR/"
cp polish.stop "$TSEARCH_DIR/"

# Create the Polish text search configuration in PostgreSQL
echo "Setting up Polish text search configuration..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE TEXT SEARCH DICTIONARY pl_ispell (
        Template = ispell,
        DictFile = polish,
        AffFile = polish,
        StopWords = polish
    );

    CREATE TEXT SEARCH CONFIGURATION pl_ispell(parser = default);

    ALTER TEXT SEARCH CONFIGURATION pl_ispell
        ALTER MAPPING FOR asciiword, asciihword, hword_asciipart, word, hword, hword_part
        WITH pl_ispell;
EOSQL

# Test the configuration
echo "Testing Polish text search configuration..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    SELECT to_tsvector('pl_ispell', 'Czuję się mniej więcej tak, jak ktoś, kto bujał w obłokach i nagle spadł.');
EOSQL

echo "Polish language support setup completed successfully!"

# Clean up
cd /
rm -rf "$TEMP_DIR"
