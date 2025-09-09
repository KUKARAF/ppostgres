-- Example backup.sql for testing Polish text search with langchain embeddings
-- This creates the langchain_pg_embedding table and inserts sample Polish data

-- Create the langchain_pg_embedding table
CREATE TABLE IF NOT EXISTS langchain_pg_embedding (
    id SERIAL PRIMARY KEY,
    collection_id UUID NOT NULL,
    embedding VECTOR(1536),
    document TEXT,
    cmetadata JSONB
);

-- Insert sample Polish text data for testing
INSERT INTO langchain_pg_embedding (collection_id, document, cmetadata) VALUES 
(
    '11e77e42-59c1-45d5-ab27-46fede747b45',
    'Zorza polarna to zjawisko świetlne występujące w górnych warstwach atmosfery. Powstaje w wyniku zderzenia naładowanych cząstek z polem magnetycznym Ziemi.',
    '{"source": "astronomy.txt", "page": 1, "topic": "aurora"}'
),
(
    '11e77e42-59c1-45d5-ab27-46fede747b45',
    'Piękna zorza borealis oświetliła nocne niebo nad Skandynawią. Zielone i różowe smugi tańczyły na firmamencie przez całą noc.',
    '{"source": "nature.txt", "page": 2, "topic": "aurora"}'
),
(
    '11e77e42-59c1-45d5-ab27-46fede747b45',
    'Czuję się mniej więcej tak, jak ktoś, kto bujał w obłokach i nagle spadł. To uczucie jest bardzo dziwne i niepokojące.',
    '{"source": "literature.txt", "page": 15, "topic": "emotions"}'
),
(
    '22e77e42-59c1-45d5-ab27-46fede747b45',
    'Warszawa jest stolicą Polski. Miasto ma bogatą historię i wiele zabytków. Pałac Kultury i Nauki to jeden z najbardziej rozpoznawalnych budynków.',
    '{"source": "geography.txt", "page": 5, "topic": "cities"}'
),
(
    '11e77e42-59c1-45d5-ab27-46fede747b45',
    'Polskie tradycje kulinarne są bardzo bogate. Pierogi, bigos, kotlet schabowy to tylko niektóre z popularnych potraw.',
    '{"source": "culture.txt", "page": 8, "topic": "food"}'
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_langchain_collection_id ON langchain_pg_embedding(collection_id);
CREATE INDEX IF NOT EXISTS idx_langchain_document_gin ON langchain_pg_embedding USING gin(to_tsvector('polish', document));

-- Grant permissions
GRANT ALL PRIVILEGES ON TABLE langchain_pg_embedding TO postgres;
GRANT USAGE, SELECT ON SEQUENCE langchain_pg_embedding_id_seq TO postgres;
