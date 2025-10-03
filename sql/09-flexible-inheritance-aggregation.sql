-- ============================================================================
-- FLEXIBLE INHERITANCE AGGREGATION QUERY
-- Aggregates portfolio holdings by dynamically inherited attributes
-- Works with variable depth, unbalanced hierarchies
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo 'AGGREGATION BY DYNAMICALLY INHERITED ATTRIBUTES'
\echo '============================================================================'

WITH RECURSIVE portfolio_tree AS (
    -- ANCHOR: Start from specified portfolio(s)
    SELECT
        p.position_id,
        p.parent_instrument_id,
        p.child_instrument_id,
        p.quantity::NUMERIC as quantity,
        p.weight::NUMERIC as cumulative_weight,
        1 as depth,
        -- Track the full inheritance path
        ARRAY[p.parent_instrument_id, p.child_instrument_id] as path_ids
    FROM positions p
    WHERE p.parent_instrument_id = 1  -- << PARAMETER: Starting portfolio
      AND p.effective_from <= '2025-01-01'::DATE
      AND (p.effective_to IS NULL OR p.effective_to > '2025-01-01'::DATE)

    UNION ALL

    -- RECURSIVE: Continue down the hierarchy
    SELECT
        p.position_id,
        p.parent_instrument_id,
        p.child_instrument_id,
        (pt.quantity * COALESCE(p.quantity, 1.0))::NUMERIC,
        (pt.cumulative_weight * COALESCE(p.weight, 1.0))::NUMERIC,
        pt.depth + 1,
        -- Extend the path array dynamically
        pt.path_ids || p.child_instrument_id
    FROM positions p
    INNER JOIN portfolio_tree pt ON p.parent_instrument_id = pt.child_instrument_id
    WHERE p.effective_from <= '2025-01-01'::DATE
      AND (p.effective_to IS NULL OR p.effective_to > '2025-01-01'::DATE)
      -- Prevent infinite loops
      AND NOT (p.child_instrument_id = ANY(pt.path_ids))
      -- Safety depth limit (configurable)
      AND pt.depth < 50
),
leaf_positions AS (
    -- Find actual leaf nodes (no hardcoded depth assumptions)
    SELECT DISTINCT ON (pt.child_instrument_id)
        pt.position_id,
        pt.child_instrument_id as security_id,
        pt.quantity,
        pt.cumulative_weight,
        pt.path_ids,
        pt.depth,
        array_length(pt.path_ids, 1) as path_length
    FROM portfolio_tree pt
    WHERE NOT EXISTS (
        SELECT 1 FROM positions p2
        WHERE p2.parent_instrument_id = pt.child_instrument_id
          AND p2.effective_from <= '2025-01-01'::DATE
          AND (p2.effective_to IS NULL OR p2.effective_to > '2025-01-01'::DATE)
    )
    -- If multiple paths to same security, take the deepest/most specific
    ORDER BY pt.child_instrument_id, pt.depth DESC
),
-- ============================================================================
-- DYNAMIC INHERITANCE RESOLUTION FOR AGGREGATION
-- ============================================================================
inherited_for_aggregation AS (
    SELECT
        lp.security_id,
        lp.quantity,
        lp.cumulative_weight,
        lp.path_ids,
        lp.depth,
        lp.path_length,

        -- Dynamically inherited region
        (SELECT fra.region
         FROM unnest(lp.path_ids) WITH ORDINALITY AS path(instrument_id, pos)
         JOIN fact_risk_attributes fra
             ON fra.instrument_id = path.instrument_id
             AND fra.attribute_date = '2025-01-01'::DATE
         WHERE fra.region IS NOT NULL
         ORDER BY path.pos DESC  -- Most specific first
         LIMIT 1) as inherited_region,

        -- Dynamically inherited sector
        (SELECT fra.sector
         FROM unnest(lp.path_ids) WITH ORDINALITY AS path(instrument_id, pos)
         JOIN fact_risk_attributes fra
             ON fra.instrument_id = path.instrument_id
             AND fra.attribute_date = '2025-01-01'::DATE
         WHERE fra.sector IS NOT NULL
         ORDER BY path.pos DESC
         LIMIT 1) as inherited_sector,

        -- Dynamically inherited asset class
        (SELECT fra.asset_class
         FROM unnest(lp.path_ids) WITH ORDINALITY AS path(instrument_id, pos)
         JOIN fact_risk_attributes fra
             ON fra.instrument_id = path.instrument_id
             AND fra.attribute_date = '2025-01-01'::DATE
         WHERE fra.asset_class IS NOT NULL
         ORDER BY path.pos DESC
         LIMIT 1) as inherited_asset_class,

        -- Dynamically inherited portfolio strategy
        (SELECT fpa.portfolio_strategy
         FROM unnest(lp.path_ids) WITH ORDINALITY AS path(instrument_id, pos)
         JOIN fact_portfolio_attributes fpa
             ON fpa.instrument_id = path.instrument_id
             AND fpa.attribute_date = '2025-01-01'::DATE
         JOIN instruments i ON i.instrument_id = path.instrument_id
         WHERE i.instrument_type = 'PORTFOLIO' AND fpa.portfolio_strategy IS NOT NULL
         ORDER BY path.pos DESC
         LIMIT 1) as inherited_strategy,

        -- Security market data
        md.price,
        md.market_cap,
        f.pe_ratio,
        fes.esg_score

    FROM leaf_positions lp
    LEFT JOIN fact_market_data md
        ON md.instrument_id = lp.security_id
        AND md.market_date = '2025-01-01'::DATE
    LEFT JOIN fact_fundamentals f
        ON f.instrument_id = lp.security_id
        AND f.reporting_date = '2024-12-31'::DATE
    LEFT JOIN fact_esg_scores fes
        ON fes.instrument_id = lp.security_id
        AND fes.score_date = '2025-01-01'::DATE
)
-- ============================================================================
-- AGGREGATION RESULTS
-- ============================================================================
SELECT
    ifa.inherited_region,
    ifa.inherited_sector,
    ifa.inherited_asset_class,
    ifa.inherited_strategy,

    -- Portfolio composition metrics
    COUNT(*) as num_holdings,
    SUM(ifa.quantity * ifa.price) as total_market_value,
    AVG(ifa.cumulative_weight) as avg_weight,
    SUM(ifa.cumulative_weight) as total_weight,

    -- Hierarchy depth statistics
    MIN(ifa.path_length) as min_hierarchy_depth,
    MAX(ifa.path_length) as max_hierarchy_depth,
    AVG(ifa.path_length::NUMERIC) as avg_hierarchy_depth,

    -- Financial metrics
    AVG(ifa.pe_ratio) as avg_pe_ratio,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ifa.pe_ratio) as median_pe_ratio,
    AVG(ifa.market_cap) as avg_market_cap,
    SUM(ifa.market_cap) as total_market_cap,

    -- ESG metrics
    AVG(ifa.esg_score) as avg_esg_score,
    MIN(ifa.esg_score) as min_esg_score,
    MAX(ifa.esg_score) as max_esg_score,

    -- Position size statistics
    AVG(ifa.quantity * ifa.price) as avg_position_value,
    MIN(ifa.quantity * ifa.price) as min_position_value,
    MAX(ifa.quantity * ifa.price) as max_position_value,
    STDDEV(ifa.quantity * ifa.price) as position_value_stddev

FROM inherited_for_aggregation ifa
WHERE ifa.price IS NOT NULL  -- Exclude securities without market data
GROUP BY
    ifa.inherited_region,
    ifa.inherited_sector,
    ifa.inherited_asset_class,
    ifa.inherited_strategy
HAVING
    -- Only show meaningful groupings
    COUNT(*) >= 5  -- At least 5 holdings
    AND SUM(ifa.quantity * ifa.price) > 1000000  -- At least $1M total value
ORDER BY
    total_market_value DESC,
    num_holdings DESC;