-- ============================================================================
-- SCHEMA: Portfolio Holdings with Multiple Fact Tables
-- ============================================================================

-- Instruments table: Portfolios, securities, etc.
CREATE TABLE instruments (
    instrument_id SERIAL PRIMARY KEY,
    instrument_type VARCHAR(50) NOT NULL,
    ticker VARCHAR(20),
    isin VARCHAR(12),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Positions/Edges in the hierarchy
CREATE TABLE positions (
    position_id SERIAL PRIMARY KEY,
    parent_instrument_id INTEGER NOT NULL REFERENCES instruments(instrument_id),
    child_instrument_id INTEGER NOT NULL REFERENCES instruments(instrument_id),
    quantity NUMERIC(18,6) NOT NULL,
    weight NUMERIC(8,6),
    effective_from DATE NOT NULL,
    effective_to DATE,
    CONSTRAINT no_self_reference CHECK (parent_instrument_id != child_instrument_id)
);

-- ============================================================================
-- MULTIPLE FACT TABLES
-- ============================================================================

-- Fact Table 1: Portfolio/Classification attributes
CREATE TABLE fact_portfolio_attributes (
    instrument_id INTEGER REFERENCES instruments(instrument_id),
    attribute_date DATE NOT NULL,

    -- Portfolio-level attributes (inheritable)
    portfolio_name VARCHAR(200),
    portfolio_strategy VARCHAR(100),
    portfolio_manager VARCHAR(100),
    benchmark VARCHAR(50),

    PRIMARY KEY (instrument_id, attribute_date)
);

-- Fact Table 2: Risk/Classification attributes
CREATE TABLE fact_risk_attributes (
    instrument_id INTEGER REFERENCES instruments(instrument_id),
    attribute_date DATE NOT NULL,

    -- Risk classification (inheritable)
    asset_class VARCHAR(50),
    region VARCHAR(50),
    sector VARCHAR(50),
    risk_rating VARCHAR(20),
    credit_rating VARCHAR(10),

    PRIMARY KEY (instrument_id, attribute_date)
);

-- Fact Table 3: Market data (leaf-only, non-inheritable)
CREATE TABLE fact_market_data (
    instrument_id INTEGER REFERENCES instruments(instrument_id),
    market_date DATE NOT NULL,

    -- Pricing data (leaf instruments only)
    price NUMERIC(18,6),
    currency VARCHAR(3),
    bid_price NUMERIC(18,6),
    ask_price NUMERIC(18,6),
    volume BIGINT,
    market_cap NUMERIC(18,2),

    PRIMARY KEY (instrument_id, market_date)
);

-- Fact Table 4: Fundamental data (leaf-only)
CREATE TABLE fact_fundamentals (
    instrument_id INTEGER REFERENCES instruments(instrument_id),
    reporting_date DATE NOT NULL,

    -- Financial metrics (leaf instruments only)
    revenue NUMERIC(18,2),
    ebitda NUMERIC(18,2),
    net_income NUMERIC(18,2),
    pe_ratio NUMERIC(8,2),
    debt_to_equity NUMERIC(8,2),

    PRIMARY KEY (instrument_id, reporting_date)
);

-- Fact Table 5: ESG scores (could be at any level)
CREATE TABLE fact_esg_scores (
    instrument_id INTEGER REFERENCES instruments(instrument_id),
    score_date DATE NOT NULL,

    -- ESG metrics (inheritable)
    esg_score NUMERIC(5,2),
    environmental_score NUMERIC(5,2),
    social_score NUMERIC(5,2),
    governance_score NUMERIC(5,2),

    PRIMARY KEY (instrument_id, score_date)
);

-- ============================================================================
-- INDEXES
-- ============================================================================

CREATE INDEX idx_positions_parent ON positions(parent_instrument_id, effective_from, effective_to);
CREATE INDEX idx_positions_child ON positions(child_instrument_id);

CREATE INDEX idx_fact_portfolio_date ON fact_portfolio_attributes(instrument_id, attribute_date);
CREATE INDEX idx_fact_risk_date ON fact_risk_attributes(instrument_id, attribute_date);
CREATE INDEX idx_fact_market_date ON fact_market_data(instrument_id, market_date);
CREATE INDEX idx_fact_fundamentals_date ON fact_fundamentals(instrument_id, reporting_date);
CREATE INDEX idx_fact_esg_date ON fact_esg_scores(instrument_id, score_date);

-- ============================================================================
-- METADATA: Define which attributes are inheritable
-- ============================================================================

CREATE TABLE attribute_metadata (
    fact_table_name VARCHAR(100),
    column_name VARCHAR(100),
    is_inheritable BOOLEAN DEFAULT FALSE,
    data_type VARCHAR(50),
    PRIMARY KEY (fact_table_name, column_name)
);

INSERT INTO attribute_metadata (fact_table_name, column_name, is_inheritable, data_type) VALUES
-- Portfolio attributes (inheritable)
('fact_portfolio_attributes', 'portfolio_name', TRUE, 'VARCHAR'),
('fact_portfolio_attributes', 'portfolio_strategy', TRUE, 'VARCHAR'),
('fact_portfolio_attributes', 'portfolio_manager', TRUE, 'VARCHAR'),
('fact_portfolio_attributes', 'benchmark', TRUE, 'VARCHAR'),

-- Risk attributes (inheritable)
('fact_risk_attributes', 'asset_class', TRUE, 'VARCHAR'),
('fact_risk_attributes', 'region', TRUE, 'VARCHAR'),
('fact_risk_attributes', 'sector', TRUE, 'VARCHAR'),
('fact_risk_attributes', 'risk_rating', TRUE, 'VARCHAR'),
('fact_risk_attributes', 'credit_rating', TRUE, 'VARCHAR'),

-- Market data (leaf-only)
('fact_market_data', 'price', FALSE, 'NUMERIC'),
('fact_market_data', 'currency', FALSE, 'VARCHAR'),
('fact_market_data', 'bid_price', FALSE, 'NUMERIC'),
('fact_market_data', 'ask_price', FALSE, 'NUMERIC'),
('fact_market_data', 'volume', FALSE, 'BIGINT'),
('fact_market_data', 'market_cap', FALSE, 'NUMERIC'),

-- Fundamentals (leaf-only)
('fact_fundamentals', 'revenue', FALSE, 'NUMERIC'),
('fact_fundamentals', 'ebitda', FALSE, 'NUMERIC'),
('fact_fundamentals', 'net_income', FALSE, 'NUMERIC'),
('fact_fundamentals', 'pe_ratio', FALSE, 'NUMERIC'),
('fact_fundamentals', 'debt_to_equity', FALSE, 'NUMERIC'),

-- ESG (inheritable)
('fact_esg_scores', 'esg_score', TRUE, 'NUMERIC'),
('fact_esg_scores', 'environmental_score', TRUE, 'NUMERIC'),
('fact_esg_scores', 'social_score', TRUE, 'NUMERIC'),
('fact_esg_scores', 'governance_score', TRUE, 'NUMERIC');