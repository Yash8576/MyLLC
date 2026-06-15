CREATE TABLE IF NOT EXISTS urls (
  id BIGSERIAL PRIMARY KEY,
  short_code VARCHAR(16) NOT NULL UNIQUE,
  long_url TEXT NOT NULL,
  clicks INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  user_id TEXT
);

CREATE INDEX IF NOT EXISTS idx_urls_short_code ON urls (short_code);
CREATE INDEX IF NOT EXISTS idx_urls_user_id ON urls (user_id);

-- Migration: add user_id to existing installs
ALTER TABLE urls ADD COLUMN IF NOT EXISTS user_id TEXT;
CREATE INDEX IF NOT EXISTS idx_urls_user_id ON urls (user_id);
