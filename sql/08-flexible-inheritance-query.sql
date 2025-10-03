-- ============================================================================
-- FLEXIBLE ATTRIBUTE INHERITANCE QUERIES
-- Handles variable depth, unbalanced hierarchies, and dynamic inheritance
-- ============================================================================

-- This approach uses PostgreSQL's array functions to dynamically traverse
-- inheritance paths regardless of hierarchy depth or balance.
--
-- KEY ADVANTAGES:
-- 1. Works with any hierarchy depth (2 levels to 20+ levels)
-- 2. Handles unbalanced trees (some branches deeper than others)
-- 3. Dynamic inheritance resolution using array operations
-- 4. No hardcoded level assumptions
-- 5. Configurable inheritance rules via metadata table

\echo ''
\echo '============================================================================'
\echo 'APPROACH 1: DYNAMIC INHERITANCE WITH LATERAL JOINS'
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
-- DYNAMIC INHERITANCE RESOLUTION
-- Use LATERAL joins to dynamically inherit from any level in the path
-- ============================================================================
inherited_attributes AS (
    SELECT
        lp.*,

        -- Portfolio attributes: inherit from most specific portfolio level
        inherited_portfolio.portfolio_name,
        inherited_portfolio.portfolio_strategy,
        inherited_portfolio.portfolio_manager,
        inherited_portfolio.benchmark,

        -- Risk attributes: inherit from most specific level (including security)
        inherited_risk.region,
        inherited_risk.sector,
        inherited_risk.asset_class,
        inherited_risk.risk_rating,

        -- ESG scores: inherit from most specific level
        inherited_esg.esg_score,
        inherited_esg.environmental_score,
        inherited_esg.social_score,
        inherited_esg.governance_score

    FROM leaf_positions lp

    -- PORTFOLIO ATTRIBUTES: Inherit from parent portfolios (not securities)
    LEFT JOIN LATERAL (
        SELECT
            fpa.portfolio_name,
            fpa.portfolio_strategy,
            fpa.portfolio_manager,
            fpa.benchmark,
            path_position
        FROM unnest(lp.path_ids) WITH ORDINALITY AS path(instrument_id, path_position)
        JOIN fact_portfolio_attributes fpa
            ON fpa.instrument_id = path.instrument_id
            AND fpa.attribute_date = '2025-01-01'::DATE
        JOIN instruments i ON i.instrument_id = path.instrument_id
        WHERE i.instrument_type = 'PORTFOLIO'  -- Only inherit from portfolios
        ORDER BY path.path_position DESC  -- Most specific first
        LIMIT 1
    ) inherited_portfolio ON true

    -- RISK ATTRIBUTES: Can inherit from any level including securities
    LEFT JOIN LATERAL (
        SELECT
            fra.region,
            fra.sector,
            fra.asset_class,
            fra.risk_rating,
            path_position
        FROM unnest(lp.path_ids) WITH ORDINALITY AS path(instrument_id, path_position)
        JOIN fact_risk_attributes fra
            ON fra.instrument_id = path.instrument_id
            AND fra.attribute_date = '2025-01-01'::DATE
        WHERE fra.region IS NOT NULL
           OR fra.sector IS NOT NULL
           OR fra.asset_class IS NOT NULL
           OR fra.risk_rating IS NOT NULL
        ORDER BY path.path_position DESC  -- Most specific first
        LIMIT 1
    ) inherited_risk ON true

    -- ESG SCORES: Can inherit from any level
    LEFT JOIN LATERAL (
        SELECT
            fes.esg_score,
            fes.environmental_score,
            fes.social_score,
            fes.governance_score,
            path_position
        FROM unnest(lp.path_ids) WITH ORDINALITY AS path(instrument_id, path_position)
        JOIN fact_esg_scores fes
            ON fes.instrument_id = path.instrument_id
            AND fes.score_date = '2025-01-01'::DATE
        WHERE fes.esg_score IS NOT NULL
        ORDER BY path.path_position DESC  -- Most specific first
        LIMIT 1
    ) inherited_esg ON true
)
-- ============================================================================
-- FINAL RESULT WITH DYNAMIC INHERITANCE
-- ============================================================================
SELECT
    ia.security_id,
    i.ticker,
    i.isin,
    ia.quantity,
    ia.cumulative_weight,
    ia.depth as hierarchy_depth,
    ia.path_length,

    -- Show the inheritance path for debugging
    array_to_string(ia.path_ids, ' → ') as inheritance_path,

    -- INHERITED ATTRIBUTES (dynamically resolved)
    ia.portfolio_name,
    ia.portfolio_strategy,
    ia.portfolio_manager,
    ia.benchmark,
    ia.region,
    ia.sector,
    ia.asset_class,
    ia.risk_rating,
    ia.esg_score,
    ia.environmental_score,

    -- LEAF-ONLY ATTRIBUTES (never inherited)
    md.price,
    md.currency,
    md.volume,
    md.market_cap,
    ia.quantity * md.price as position_value,

    f.pe_ratio,
    f.debt_to_equity,
    f.revenue,

    -- Security-specific risk data (not inherited)
    leaf_risk.credit_rating

FROM inherited_attributes ia
JOIN instruments i ON i.instrument_id = ia.security_id
LEFT JOIN fact_market_data md
    ON md.instrument_id = ia.security_id
    AND md.market_date = '2025-01-01'::DATE
LEFT JOIN fact_fundamentals f
    ON f.instrument_id = ia.security_id
    AND f.reporting_date = '2024-12-31'::DATE
LEFT JOIN fact_risk_attributes leaf_risk
    ON leaf_risk.instrument_id = ia.security_id
    AND leaf_risk.attribute_date = '2025-01-01'::DATE

ORDER BY (ia.quantity * md.price) DESC NULLS LAST;
--LIMIT 20;
