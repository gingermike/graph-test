INSERT INTO instruments (instrument_type, ticker, isin)
SELECT 'PORTFOLIO', 'MASTER' || s, NULL
FROM generate_series(1, 5) s;

-- Create Regional Funds (Level 2)
INSERT INTO instruments (instrument_type, ticker, isin)
SELECT 'PORTFOLIO', 'REGIONAL' || s, NULL
FROM generate_series(1, 25) s;

-- Create Strategy Funds (Level 3)
INSERT INTO instruments (instrument_type, ticker, isin)
SELECT 'PORTFOLIO', 'STRATEGY' || s, NULL
FROM generate_series(1, 250) s;

-- Create 50,000 Securities (Level 4)
-- 40,000 Equities
INSERT INTO instruments (instrument_type, ticker, isin)
SELECT
    'EQUITY',
    'EQ' || LPAD(s::text, 5, '0'),
    'US' || LPAD(((s::BIGINT * 12345) % 999999999)::text, 9, '0')
FROM generate_series(1, 40000) s;

-- 10,000 Bonds
INSERT INTO instruments (instrument_type, ticker, isin)
SELECT
    'BOND',
    'BD' || LPAD(s::text, 5, '0'),
    'US' || LPAD(((s::BIGINT * 98765) % 999999999)::text, 9, '0')
FROM generate_series(1, 10000) s;

-- ============================================================================
-- CREATE POSITION RELATIONSHIPS
-- ============================================================================

-- Level 1 -> Level 2: Each Master Fund holds 5 Regional Funds
INSERT INTO positions (parent_instrument_id, child_instrument_id, quantity, weight, effective_from, effective_to)
SELECT
    ((r.instrument_id - 6) / 5) + 1 as master_id,  -- Distribute regionals evenly
    r.instrument_id as regional_id,
    1.0,
    0.20,  -- 20% weight each (5 holdings)
    '2025-01-01'::DATE,
    NULL
FROM instruments r
WHERE r.instrument_id BETWEEN 6 AND 30;  -- Regional funds

-- Level 2 -> Level 3: Each Regional Fund holds 10 Strategy Funds
INSERT INTO positions (parent_instrument_id, child_instrument_id, quantity, weight, effective_from, effective_to)
SELECT
    6 + ((s.instrument_id - 31) / 10) as regional_id,  -- Distribute strategies evenly
    s.instrument_id as strategy_id,
    1.0,
    0.10,  -- 10% weight each (10 holdings)
    '2025-01-01'::DATE,
    NULL
FROM instruments s
WHERE s.instrument_id BETWEEN 31 AND 280;  -- Strategy funds

-- Level 3 -> Level 4: Distribute 50,000 securities across 250 strategy funds
-- Each strategy fund gets ~200 securities on average
-- Using random distribution for more realistic portfolio composition
INSERT INTO positions (parent_instrument_id, child_instrument_id, quantity, weight, effective_from, effective_to)
SELECT
    strategy_id,
    security_id,
    (100 + random() * 9900)::NUMERIC(18,6) as quantity,  -- 100-10,000 shares
    weight,
    '2025-01-01'::DATE,
    NULL
FROM (
    SELECT
        31 + floor(random() * 250)::INTEGER as strategy_id,  -- Random strategy fund
        s.instrument_id as security_id,
        (0.001 + random() * 0.009)::NUMERIC(8,6) as weight  -- 0.1% - 1% weight
    FROM instruments s
    WHERE s.instrument_id > 280  -- Securities only
    ORDER BY random()
) distribution
-- Ensure each security appears in at least one fund
WHERE security_id > 280
ON CONFLICT DO NOTHING;

-- Ensure every security is held by at least one strategy fund
INSERT INTO positions (parent_instrument_id, child_instrument_id, quantity, weight, effective_from, effective_to)
SELECT
    31 + (s.instrument_id % 250) as strategy_id,  -- Assign to a strategy fund
    s.instrument_id,
    (100 + random() * 9900)::NUMERIC(18,6),
    (0.001 + random() * 0.004)::NUMERIC(8,6),
    '2025-01-01'::DATE,
    NULL
FROM instruments s
WHERE s.instrument_id > 280
  AND NOT EXISTS (
    SELECT 1 FROM positions p
    WHERE p.child_instrument_id = s.instrument_id
  )
ON CONFLICT DO NOTHING;

-- ============================================================================
-- GENERATE FACT TABLE DATA
-- ============================================================================

-- Portfolio Attributes (all portfolios)
INSERT INTO fact_portfolio_attributes (instrument_id, attribute_date, portfolio_name, portfolio_strategy, portfolio_manager, benchmark)
SELECT
    i.instrument_id,
    '2025-01-01'::DATE,
    CASE
        WHEN i.instrument_id <= 5 THEN 'Global Master Fund ' || i.instrument_id
        WHEN i.instrument_id <= 30 THEN 'Regional Fund ' || (i.instrument_id - 5)
        ELSE 'Strategy Fund ' || (i.instrument_id - 30)
    END,
    (ARRAY['Growth', 'Value', 'Core', 'Aggressive Growth', 'Conservative', 'Balanced', 'Income', 'Momentum'])[1 + (i.instrument_id % 8)],
    (ARRAY['John Smith', 'Jane Doe', 'Mike Johnson', 'Sarah Wilson', 'David Brown', 'Lisa Davis', 'Tom Anderson', 'Emily White'])[1 + (i.instrument_id % 8)],
    (ARRAY['S&P 500', 'NASDAQ 100', 'Russell 2000', 'MSCI World', 'Bloomberg Aggregate', 'FTSE 100', 'MSCI EAFE', 'Russell 3000'])[1 + (i.instrument_id % 8)]
FROM instruments i
WHERE i.instrument_type = 'PORTFOLIO';

-- Risk Attributes (all instruments)
INSERT INTO fact_risk_attributes (instrument_id, attribute_date, asset_class, region, sector, risk_rating, credit_rating)
SELECT
    i.instrument_id,
    '2025-01-01'::DATE,
    CASE i.instrument_type
        WHEN 'PORTFOLIO' THEN (ARRAY['Equity', 'Fixed Income', 'Mixed', 'Alternative'])[1 + (i.instrument_id % 4)]
        WHEN 'EQUITY' THEN 'Equity'
        WHEN 'BOND' THEN 'Fixed Income'
    END,
    (ARRAY['North America', 'Europe', 'Asia Pacific', 'Emerging Markets', 'Global', 'Latin America', 'EMEA', 'Frontier Markets'])[1 + (i.instrument_id % 8)],
    CASE i.instrument_type
        WHEN 'EQUITY' THEN (ARRAY['Technology', 'Healthcare', 'Financial Services', 'Consumer Goods', 'Energy', 'Materials', 'Industrials', 'Utilities', 'Real Estate', 'Communication Services', 'Consumer Discretionary', 'Consumer Staples'])[1 + (i.instrument_id % 12)]
        WHEN 'BOND' THEN (ARRAY['Government', 'Corporate', 'Municipal', 'High Yield', 'Investment Grade', 'Emerging Market'])[1 + (i.instrument_id % 6)]
        ELSE NULL
    END,
    (ARRAY['Low', 'Medium-Low', 'Medium', 'Medium-High', 'High'])[1 + (i.instrument_id % 5)],
    CASE i.instrument_type
        WHEN 'BOND' THEN (ARRAY['AAA', 'AA+', 'AA', 'AA-', 'A+', 'A', 'A-', 'BBB+', 'BBB', 'BBB-'])[1 + (i.instrument_id % 10)]
        WHEN 'EQUITY' THEN (ARRAY['AAA', 'AA+', 'AA', 'A+', 'A'])[1 + (i.instrument_id % 5)]
        ELSE NULL
    END
FROM instruments i;

-- Market Data (securities only - 50k records)
INSERT INTO fact_market_data (instrument_id, market_date, price, currency, bid_price, ask_price, volume, market_cap)
SELECT
    i.instrument_id,
    '2025-01-01'::DATE,
    (5 + random() * 495)::NUMERIC(18,6),  -- Prices $5-$500
    'USD',
    (5 + random() * 495 - 0.05)::NUMERIC(18,6),
    (5 + random() * 495 + 0.05)::NUMERIC(18,6),
    (10000 + random() * 10000000)::BIGINT,  -- Volume 10K-10M
    (1000000 + random() * 999000000000)::NUMERIC(18,2)  -- Market cap $1M-$999B
FROM instruments i
WHERE i.instrument_type IN ('EQUITY', 'BOND');

-- Fundamentals (equities only - 40k records)
INSERT INTO fact_fundamentals (instrument_id, reporting_date, revenue, ebitda, net_income, pe_ratio, debt_to_equity)
SELECT
    i.instrument_id,
    '2024-12-31'::DATE,
    (100000 + random() * 10000000000)::NUMERIC(18,2),  -- Revenue $100K-$10B
    (10000 + random() * 3000000000)::NUMERIC(18,2),
    (5000 + random() * 2500000000)::NUMERIC(18,2),
    (5 + random() * 45)::NUMERIC(8,2),  -- P/E ratio 5-50
    (random() * 3)::NUMERIC(8,2)  -- Debt/Equity 0-3
FROM instruments i
WHERE i.instrument_type = 'EQUITY';

-- ESG Scores (all instruments)
INSERT INTO fact_esg_scores (instrument_id, score_date, esg_score, environmental_score, social_score, governance_score)
SELECT
    i.instrument_id,
    '2025-01-01'::DATE,
    (40 + random() * 60)::NUMERIC(5,2),  -- ESG score 40-100
    (40 + random() * 60)::NUMERIC(5,2),
    (40 + random() * 60)::NUMERIC(5,2),
    (40 + random() * 60)::NUMERIC(5,2)
FROM instruments i;

-- ============================================================================
-- SHOW STATISTICS
-- ============================================================================

SELECT
    'Hierarchy Statistics' as category,
    'Total Instruments' as metric,
    COUNT(*) as count
FROM instruments
UNION ALL
SELECT 'Hierarchy Statistics', 'Master Funds (L1)', COUNT(*) FROM instruments WHERE instrument_id <= 5
UNION ALL
SELECT 'Hierarchy Statistics', 'Regional Funds (L2)', COUNT(*) FROM instruments WHERE instrument_id BETWEEN 6 AND 30
UNION ALL
SELECT 'Hierarchy Statistics', 'Strategy Funds (L3)', COUNT(*) FROM instruments WHERE instrument_id BETWEEN 31 AND 280
UNION ALL
SELECT 'Hierarchy Statistics', 'Securities (L4)', COUNT(*) FROM instruments WHERE instrument_id > 280
UNION ALL
SELECT 'Hierarchy Statistics', 'Total Positions', COUNT(*) FROM positions
UNION ALL
SELECT 'Fact Tables', 'Market Data Records', COUNT(*) FROM fact_market_data
UNION ALL
SELECT 'Fact Tables', 'Fundamental Records', COUNT(*) FROM fact_fundamentals
UNION ALL
SELECT 'Fact Tables', 'ESG Score Records', COUNT(*) FROM fact_esg_scores
ORDER BY category, count DESC;