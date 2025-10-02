#!/bin/bash

# Script to recreate the full database with 50k securities hierarchy

set -e

echo "=================================================="
echo "Portfolio Database Recreation Script"
echo "=================================================="
echo ""

# Load environment variables
source "$(dirname "$0")/../.env"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}This will destroy and recreate your database!${NC}"
echo "Do you want to continue? (yes/no)"
read -r response

if [[ ! "$response" =~ ^(yes|y)$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo -e "${RED}Stopping containers and removing volumes...${NC}"
docker-compose down -v

echo ""
echo -e "${GREEN}Starting fresh PostgreSQL container...${NC}"
docker-compose up -d

echo ""
echo "Waiting for database to be ready (PostgreSQL latest takes longer to start)..."
for i in {1..60}; do
    if docker-compose exec -T postgres pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" > /dev/null 2>&1; then
        echo -e "${GREEN}Database is ready!${NC}"
        break
    fi
    if [ $i -eq 60 ]; then
        echo -e "${RED}Database failed to start. Check logs with: docker-compose logs postgres${NC}"
        exit 1
    fi
    echo -n "."
    sleep 1
done

echo ""
echo "Database auto-initialization in progress..."
echo "PostgreSQL will automatically run SQL files from sql/ directory on first startup"
echo ""

# The auto-init will now run all files including 99-massive-data-load.sql
echo "Database will auto-initialize with all SQL files..."
sleep 5  # Give it time to complete

# Wait for the massive data load to complete
echo "Waiting for 50K securities load to complete..."
for i in {1..180}; do
    COUNT=$(docker-compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -c "SELECT COUNT(*) FROM instruments;" 2>/dev/null | tr -d ' ')
    if [ "$COUNT" = "50280" ]; then
        echo -e "${GREEN}Massive data load completed!${NC}"
        break
    fi
    if [ $i -eq 180 ]; then
        echo -e "${YELLOW}Data load taking longer than expected...${NC}"
        break
    fi
    if [ $((i % 15)) -eq 0 ]; then
        echo "Still loading data... ($i/180 seconds, current count: $COUNT)"
    fi
    sleep 1
done

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Database initialization completed successfully!${NC}"
else
    echo -e "${RED}Database initialization failed!${NC}"
    exit 1
fi

echo "Final step: Verifying data load..."
docker-compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "
    SELECT
        'Database Statistics' as category,
        '===================' as value
    UNION ALL
    SELECT 'Total Instruments:', COUNT(*)::text FROM instruments
    UNION ALL
    SELECT '  - Master Funds (L1):', COUNT(*)::text FROM instruments WHERE instrument_id <= 5
    UNION ALL
    SELECT '  - Regional Funds (L2):', COUNT(*)::text FROM instruments WHERE instrument_id BETWEEN 6 AND 30
    UNION ALL
    SELECT '  - Strategy Funds (L3):', COUNT(*)::text FROM instruments WHERE instrument_id BETWEEN 31 AND 280
    UNION ALL
    SELECT '  - Securities (L4):', COUNT(*)::text FROM instruments WHERE instrument_id > 280
    UNION ALL
    SELECT 'Total Positions:', COUNT(*)::text FROM positions
    UNION ALL
    SELECT 'Market Data Records:', COUNT(*)::text FROM fact_market_data
    UNION ALL
    SELECT 'ESG Score Records:', COUNT(*)::text FROM fact_esg_scores;"

echo ""
echo -e "${GREEN}✓ Database recreation complete!${NC}"
echo ""
echo "You can now:"
echo "  1. Connect to the database: ./scripts/psql.sh"
echo "  2. Run example queries: docker-compose exec -T postgres psql -U portfolio_user -d portfolio -f /docker-entrypoint-initdb.d/07-optimized-inheritance-query.sql"
echo "  3. Test performance: ./scripts/test-performance.sh"
echo ""
echo "The database contains:"
echo "  • 4-level hierarchy (Master → Regional → Strategy → Securities)"
echo "  • 50,000 securities distributed across 250 strategy funds"
echo "  • Full fact table data (market data, fundamentals, ESG, risk attributes)"
echo "  • Optimized indexes for inheritance queries"