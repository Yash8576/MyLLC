ALTER TABLE content_items DROP CONSTRAINT IF EXISTS valid_content_type;

ALTER TABLE content_items ADD CONSTRAINT valid_content_type CHECK (content_type IN ('video', 'reel', 'photo'));
