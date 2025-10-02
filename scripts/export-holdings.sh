#!/bin/bash

# Load environment variables
source "$(dirname "$0")/../.env"

# Export holdings to CSV format
docker exec portfolio-postgres psql \
    -U "$POSTGRES_USER" \
    -d "$POSTGRES_DB" \
    -f /docker-entrypoint-initdb.d/03-queries.sql \
    --csv \
    --quiet \
    2>/dev/null | head -n 20