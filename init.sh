#!/bin/bash
set -e

# Wait until PostgreSQL is ready
until pg_isready; do
  echo "Waiting for PostgreSQL to be ready..."
  sleep 2
done

echo "Starting restore process..."

# Check if dump file exists
if [ ! -f "${DUMP_PATH}" ]; then
    echo "ERROR: Dump file not found: ${DUMP_PATH}"
    echo "Listing available dumps:"
    ls -la "$(dirname "${DUMP_PATH}")"
    exit 1
fi

echo "Dump file found. Starting restoration..."

# Restore using pg_restore with additional options
pg_restore -v -U "$POSTGRES_USER" \
    --dbname="$POSTGRES_DB" \
    --no-owner \
    --role="$POSTGRES_USER" \
    --clean \
    --if-exists \
    --no-acl \
    --no-comments \
    --single-transaction \
    "${DUMP_PATH}" || {
        echo "pg_restore encountered some errors, trying with psql..."
        psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" < "${DUMP_PATH}"
    }

# Check if tables were restored
echo "Checking tables after restoration..."
psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "\dt"

echo "Setting up permissions..."

# Grant necessary permissions
psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \"$POSTGRES_USER\";"
psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO \"$POSTGRES_USER\";"
psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO \"$POSTGRES_USER\";"

# Generate SQL file with INSERT statements
echo "Generating SQL file with database tables and INSERT statements..."
OUTPUT_SQL="/dumps/database_tables_and_inserts.sql"

# Add drop and create tables first
pg_dump -U "$POSTGRES_USER" \
    --dbname="$POSTGRES_DB" \
    --schema-only \
    --no-owner \
    --no-privileges > "$OUTPUT_SQL"

# Then add INSERT statements for all tables
pg_dump -U "$POSTGRES_USER" \
    --dbname="$POSTGRES_DB" \
    --data-only \
    --column-inserts \
    --no-owner \
    --no-privileges >> "$OUTPUT_SQL"

echo "SQL file generated at: $OUTPUT_SQL"

# Check database status
echo "Final database status:"
echo "1. Listing tables:"
psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "\dt"
echo "2. Counting records in tables:"
psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "
SELECT schemaname, relname, n_live_tup 
FROM pg_stat_user_tables 
ORDER BY n_live_tup DESC;"

echo "Restore process completed" 