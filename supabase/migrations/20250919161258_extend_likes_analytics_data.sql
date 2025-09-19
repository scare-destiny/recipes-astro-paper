-- Add analytics fields to post_likes table
ALTER TABLE post_likes 
ADD COLUMN analytics_data JSON
