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
# Try multiple sources for Polish dictionary
if ! wget -O polish-dict.tar.bz2 "https://sjp.pl/slownik/ort/sjp-ispell-pl-20240101-src.tar.bz2" 2>/dev/null; then
    if ! wget -O polish-dict.tar.bz2 "https://sjp.pl/slownik/ort/sjp-ispell-pl-20230101-src.tar.bz2" 2>/dev/null; then
        if ! wget -O polish-dict.tar.bz2 "https://sjp.pl/slownik/ort/sjp-ispell-pl-20220101-src.tar.bz2" 2>/dev/null; then
            if ! wget -O polish-dict.tar.bz2 "https://sjp.pl/slownik/ort/sjp-ispell-pl-20210101-src.tar.bz2" 2>/dev/null; then
                # Fallback to a known working source
                echo "Primary sources failed, trying alternative source..."
                if ! wget -O polish-dict.tar.bz2 "https://github.com/LibreOffice/dictionaries/raw/master/pl_PL/pl_PL.dic" 2>/dev/null; then
                    echo "Warning: Could not download Polish dictionary. Skipping Polish language setup."
                    echo "PostgreSQL will still work normally, but without Polish text search support."
                    exit 0
                fi
                # Create a simple dictionary structure for LibreOffice format
                echo "Converting LibreOffice dictionary format..."
                mv polish-dict.tar.bz2 polish.dict
                echo "# Simple Polish affix file" > polish.affix
                echo "SET UTF-8" >> polish.affix
                echo "# Basic Polish stopwords" > polish.stop
                echo -e "a\ni\nw\nz\nna\ndo\nje\nto\nnie\nże\naby\nale\nani\nbez\nbo\nby\nco\nczy\ndla\ngo\nich\nile\nim\nja\njak\nje\njeż\nli\nlub\nmy\nod\npo\nsi\ntej\ntem\ntu\nty\nwe\nże" >> polish.stop
                # Skip extraction step
                SKIP_EXTRACT=1
            fi
        fi
    fi
fi

# Extract the archive
if [ "$SKIP_EXTRACT" != "1" ]; then
    echo "Extracting Polish dictionary..."
    if ! tar -xjf polish-dict.tar.bz2; then
        echo "Warning: Failed to extract Polish dictionary. Skipping Polish language setup."
        exit 0
    fi
    cd sjp-ispell-pl-*
fi

# Download Polish stopwords from GitHub
if [ "$SKIP_EXTRACT" != "1" ]; then
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
fi

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
if [ -f polish.affix ] && [ -f polish.dict ] && [ -f polish.stop ]; then
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
else
    echo "Warning: Polish dictionary files not found. Skipping text search configuration."
fi

echo "Polish language support setup completed successfully!"

# Clean up
cd /
rm -rf "$TEMP_DIR"
