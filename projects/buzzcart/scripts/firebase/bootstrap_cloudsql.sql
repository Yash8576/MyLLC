-- Bootstrap script for Cloud SQL access through a built-in login.
-- Run with: psql -v chatbot_password='...' -f scripts/firebase/bootstrap_cloudsql.sql

\set ON_ERROR_STOP on

-- Create the application database if it does not exist.
SELECT format('CREATE DATABASE %I OWNER buzzcart_app', 'buzzcart-daeb6-database')
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_database
    WHERE datname = 'buzzcart-daeb6-database'
)
\gexec

-- Create or refresh the read-only chatbot role.
SELECT format('CREATE ROLE buzzcart_chatbot_ro LOGIN PASSWORD %L', :'chatbot_password')
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_roles
    WHERE rolname = 'buzzcart_chatbot_ro'
)
\gexec

SELECT format('ALTER ROLE buzzcart_chatbot_ro LOGIN PASSWORD %L', :'chatbot_password')
WHERE EXISTS (
    SELECT 1
    FROM pg_roles
    WHERE rolname = 'buzzcart_chatbot_ro'
)
\gexec

GRANT CONNECT ON DATABASE "buzzcart-daeb6-database" TO buzzcart_app;
GRANT CONNECT ON DATABASE "buzzcart-daeb6-database" TO buzzcart_chatbot_ro;

\connect "buzzcart-daeb6-database"

REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT CREATE ON SCHEMA public TO buzzcart_app;

GRANT USAGE ON SCHEMA public TO buzzcart_app;
GRANT USAGE ON SCHEMA public TO buzzcart_chatbot_ro;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
ON ALL TABLES IN SCHEMA public FROM buzzcart_chatbot_ro;
REVOKE USAGE, UPDATE
ON ALL SEQUENCES IN SCHEMA public FROM buzzcart_chatbot_ro;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO buzzcart_app;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO buzzcart_app;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO buzzcart_chatbot_ro;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO buzzcart_chatbot_ro;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO buzzcart_app;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO buzzcart_app;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT ON TABLES TO buzzcart_chatbot_ro;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT ON SEQUENCES TO buzzcart_chatbot_ro;