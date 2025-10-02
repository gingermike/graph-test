#!/bin/bash

# Load environment variables
source "$(dirname "$0")/../.env"

echo "Running portfolio queries..."
echo

docker exec portfolio-postgres psql \
    -U "$POSTGRES_USER" \
    -d "$POSTGRES_DB" \
    -f /docker-entrypoint-initdb.d/03-queries.sql