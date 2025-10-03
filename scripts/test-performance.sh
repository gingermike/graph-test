#!/bin/bash

# Load environment variables
source "$(dirname "$0")/../.env"

echo "=== Performance Testing on Large Dataset ==="
echo

echo "1. Database Size Statistics:"
docker compose exec -T postgres psql \
    -U "$POSTGRES_USER" \
    -d "$POSTGRES_DB" \
    -c "SELECT
        'Total Instruments' as metric, COUNT(*) as count FROM instruments
        UNION ALL
        SELECT 'Total Positions', COUNT(*) FROM positions
        UNION ALL
        SELECT 'Total Market Data Records', COUNT(*) FROM fact_market_data;"

echo
echo "2. Testing Simple Query (All positions for Portfolio 1):"
time docker compose exec -T postgres psql \
    -U "$POSTGRES_USER" \
    -d "$POSTGRES_DB" \
    -c "SELECT COUNT(*) as direct_holdings
        FROM positions
        WHERE parent_instrument_id = 1;" 2>&1 | grep -E 'direct_holdings|real'

echo
echo "3. Testing Recursive Query WITHOUT Inheritance (Portfolio 1):"
time docker compose exec -T postgres psql \
    -U "$POSTGRES_USER" \
    -d "$POSTGRES_DB" \
    -c "WITH RECURSIVE portfolio_tree AS (
            SELECT p.position_id, p.parent_instrument_id, p.child_instrument_id,
                   p.quantity::NUMERIC, 1 as depth
            FROM positions p
            WHERE p.parent_instrument_id = 1
            UNION ALL
            SELECT p.position_id, p.parent_instrument_id, p.child_instrument_id,
                   p.quantity::NUMERIC, pt.depth + 1
            FROM positions p
            INNER JOIN portfolio_tree pt ON p.parent_instrument_id = pt.child_instrument_id
            WHERE pt.depth < 10
        )
        SELECT COUNT(*) as total_holdings, MAX(depth) as max_depth
        FROM portfolio_tree;" 2>&1 | grep -E 'total_holdings|real'

echo
echo "4. Testing Query with ONE Fact Table Join (Portfolio 1):"
time docker compose exec -T postgres psql \
    -U "$POSTGRES_USER" \
    -d "$POSTGRES_DB" \
    -c "WITH RECURSIVE portfolio_tree AS (
            SELECT p.child_instrument_id, p.quantity::NUMERIC
            FROM positions p
            WHERE p.parent_instrument_id = 1
            UNION ALL
            SELECT p.child_instrument_id, pt.quantity * p.quantity
            FROM positions p
            INNER JOIN portfolio_tree pt ON p.parent_instrument_id = pt.child_instrument_id
        )
        SELECT COUNT(*), SUM(pt.quantity * fmd.price) as total_value
        FROM portfolio_tree pt
        LEFT JOIN fact_market_data fmd
            ON fmd.instrument_id = pt.child_instrument_id
        WHERE NOT EXISTS (
            SELECT 1 FROM positions p2
            WHERE p2.parent_instrument_id = pt.child_instrument_id
        );" 2>&1 | grep -E 'count|real'

echo
echo "5. Testing Aggregation Query (Top 10 regions by holdings):"
time docker compose exec -T postgres psql \
    -U "$POSTGRES_USER" \
    -d "$POSTGRES_DB" \
    -c "SELECT fra.region, COUNT(*) as holdings_count
        FROM positions p
        JOIN fact_risk_attributes fra ON fra.instrument_id = p.child_instrument_id
        WHERE p.parent_instrument_id IN (SELECT instrument_id FROM instruments WHERE instrument_type = 'PORTFOLIO' LIMIT 5)
        GROUP BY fra.region
        ORDER BY holdings_count DESC
        LIMIT 10;" 2>&1 | grep -E 'region|real'

echo
echo "=== Performance Summary ==="
echo "Dataset: ~48K positions, ~6K instruments, ~6K fact records per table"