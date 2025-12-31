-- PostgreSQL initialization script for Synapse
-- This script is run when the database is first created

-- Create database and user if they don't exist
-- Note: POSTGRES_USER and POSTGRES_DB are set via environment variables
-- This script is mainly for reference and additional setup if needed

-- Set timezone
SET timezone = 'UTC';

-- Optimize for low-resource servers
-- These settings will be applied via postgresql.conf or environment variables
-- shared_buffers = 256MB (for 2-4GB RAM servers)
-- work_mem = 4MB
-- maintenance_work_mem = 64MB
-- effective_cache_size = 1GB

