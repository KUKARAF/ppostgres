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
# Use the current working URL from sjp.pl
if ! wget -O polish-dict.tar.bz2 "https://sjp.pl/sl/ort/sjp-ispell-pl-20250901-src.tar.bz2" 2>/dev/null; then
    echo "Warning: Could not download Polish dictionary. Skipping Polish language setup."
    echo "PostgreSQL will still work normally, but without Polish text search support."
    exit 0
fi

# Extract the archive
echo "Extracting Polish dictionary..."
if ! tar -xjf polish-dict.tar.bz2; then
    echo "Warning: Failed to extract Polish dictionary. Skipping Polish language setup."
    exit 0
fi
cd sjp-ispell-pl-*

# Download Polish stopwords from GitHub
echo "Downloading Polish stopwords..."
if ! wget -O polish.stopwords.txt "https://raw.githubusercontent.com/bieli/stopwords-pl/master/polish.stopwords.txt" 2>/dev/null; then
    echo "Warning: Could not download stopwords, using basic set..."
    echo -e "a\ni\nw\nz\nna\ndo\nje\nto\nnie\nże\naby\nale\nani\nbez\nbo\nby\nco\nczy\ndla\ngo\nich\nile\nim\nja\njak\nje\njeż\nli\nlub\nmy\nod\npo\nsi\ntej\ntem\ntu\nty\nwe\nże" > polish.stopwords.txt
fi

# Convert encodings to UTF-8 and rename files
echo "Converting encodings..."
if [ -f polish.aff ]; then
    iconv -f ISO_8859-2 -t utf-8 polish.aff > polish.affix 2>/dev/null || cp polish.aff polish.affix
fi
if [ -f polish.all ]; then
    iconv -f ISO_8859-2 -t utf-8 polish.all > polish.dict 2>/dev/null || cp polish.all polish.dict
fi
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
