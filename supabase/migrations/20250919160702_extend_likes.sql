-- Add analytics fields to post_likes table
ALTER TABLE post_likes 
ADD COLUMN user_agent TEXT,
ADD COLUMN ip_address INET,
ADD COLUMN country TEXT,
ADD COLUMN city TEXT,
ADD COLUMN region TEXT,
ADD COLUMN timezone TEXT,
ADD COLUMN referrer TEXT,
ADD COLUMN language TEXT;
ADD COLUMN analytics JSON;

-- Create index for analytics queries
CREATE INDEX idx_post_likes_country ON post_likes(country);
CREATE INDEX idx_post_likes_city ON post_likes(city);
CREATE INDEX idx_post_likes_created_at ON post_likes(created_at);
