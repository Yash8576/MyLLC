-- WhatsApp-style delivery receipts: track when a message reached the
-- recipient's device (delivered_at), separate from when they read it
-- (is_read). Status ladder: sent -> delivered -> read.

ALTER TABLE messages
    ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMP WITH TIME ZONE;

-- Anything already read was necessarily delivered.
UPDATE messages
SET delivered_at = created_at
WHERE is_read = TRUE
  AND delivered_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_messages_undelivered
    ON messages(conversation_id)
    WHERE delivered_at IS NULL;
