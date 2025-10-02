-- ============================================================================
-- DEPRECATED: OLD HARDCODED INHERITANCE APPROACH
-- This file has been replaced by 08-flexible-inheritance-query.sql
-- ============================================================================

-- The queries in this file assume a fixed 4-level hierarchy structure
-- and won't work properly with unbalanced or variable-depth hierarchies.
--
-- Use these files instead:
-- - 08-flexible-inheritance-query.sql (for detailed holdings with inheritance)
-- - 09-flexible-inheritance-aggregation.sql (for aggregated analysis)
--
-- These new approaches use dynamic path traversal and work with any
-- hierarchy depth or structure.

\echo ''
\echo '============================================================================'
\echo 'DEPRECATED: This file contains old hardcoded inheritance queries'
\echo 'Use 08-flexible-inheritance-query.sql or 09-flexible-inheritance-aggregation.sql instead'
\echo '============================================================================'