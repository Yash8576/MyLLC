-- ============================================================================
-- Migration: Review Helpful Votes
-- Description: Add table to track which users marked reviews as helpful
-- ============================================================================

-- Create table to track helpful votes on reviews
CREATE TABLE review_helpful_votes (
    review_id UUID NOT NULL REFERENCES product_ratings(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    voted_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (review_id, user_id)
);

-- Create indexes for better query performance
CREATE INDEX idx_review_helpful_votes_review_id ON review_helpful_votes(review_id);
CREATE INDEX idx_review_helpful_votes_user_id ON review_helpful_votes(user_id);

-- Add comment to table
COMMENT ON TABLE review_helpful_votes IS 'Tracks which users marked which reviews as helpful. Each user can vote once per review.';
