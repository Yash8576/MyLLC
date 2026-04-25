CREATE TABLE IF NOT EXISTS content_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_id UUID NOT NULL REFERENCES content_items(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    comment_text TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_content_comments_content_created
    ON content_comments(content_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_content_comments_user
    ON content_comments(user_id);

CREATE OR REPLACE FUNCTION sync_content_comment_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE content_items
        SET comment_count = comment_count + 1
        WHERE id = NEW.content_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE content_items
        SET comment_count = GREATEST(comment_count - 1, 0)
        WHERE id = OLD.content_id;
        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_sync_content_comment_count ON content_comments;

CREATE TRIGGER trigger_sync_content_comment_count
AFTER INSERT OR DELETE ON content_comments
FOR EACH ROW
EXECUTE FUNCTION sync_content_comment_count();
