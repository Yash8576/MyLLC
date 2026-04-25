-- Run this in Cloud SQL PostgreSQL as an admin user.
-- Replace the placeholder passwords before running.

-- 1) App user (read/write)
DO
$$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'buzzcart_app') THEN
        CREATE ROLE buzzcart_app LOGIN PASSWORD 'C)?Rl)rjecxpzF?H';
    END IF;
END
$$;

-- 2) Chatbot user (read-only)
DO
$$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'buzzcart_chatbot_ro') THEN
        CREATE ROLE buzzcart_chatbot_ro LOGIN PASSWORD 'N7vQ2pLm8sTx4kRf';
    END IF;
END
$$;

-- 3) Database connect access
GRANT CONNECT ON DATABASE "buzzcart-daeb6-database" TO buzzcart_app;
GRANT CONNECT ON DATABASE "buzzcart-daeb6-database" TO buzzcart_chatbot_ro;

-- 3.1) Cloud SQL built-in users may inherit elevated role membership.
-- Remove elevated role if present to enforce least privilege.
DO
$$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'cloudsqlsuperuser') THEN
        REVOKE cloudsqlsuperuser FROM buzzcart_app;
        REVOKE cloudsqlsuperuser FROM buzzcart_chatbot_ro;
    END IF;
END
$$;

-- 4) Schema access
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT CREATE ON SCHEMA public TO buzzcart_app;
GRANT USAGE ON SCHEMA public TO buzzcart_app;
GRANT USAGE ON SCHEMA public TO buzzcart_chatbot_ro;

-- Ensure chatbot role stays read-only at schema object level.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
ON ALL TABLES IN SCHEMA public FROM buzzcart_chatbot_ro;
REVOKE USAGE, UPDATE
ON ALL SEQUENCES IN SCHEMA public FROM buzzcart_chatbot_ro;

-- 5) Existing object privileges
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO buzzcart_app;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO buzzcart_app;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO buzzcart_chatbot_ro;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO buzzcart_chatbot_ro;

-- 6) Default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO buzzcart_app;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO buzzcart_app;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT ON TABLES TO buzzcart_chatbot_ro;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT ON SEQUENCES TO buzzcart_chatbot_ro;
