#!/bin/bash

# Load environment variables
source "$(dirname "$0")/../.env"

# Connect to PostgreSQL
docker exec -it portfolio-postgres psql \
    -U "$POSTGRES_USER" \
    -d "$POSTGRES_DB"