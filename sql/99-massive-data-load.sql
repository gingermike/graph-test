-- ============================================================================
-- MASSIVE DATA LOAD
-- Schema is auto-loaded by PostgreSQL, this loads the full 50K securities hierarchy
-- ============================================================================

\echo 'Loading 50K securities hierarchy (this may take 1-2 minutes)...'

\i /docker-entrypoint-initdb.d/06-massive-hierarchy.sql

\echo 'Massive data load complete!'