-- Create the likes table
CREATE TABLE post_likes (
  id BIGSERIAL PRIMARY KEY,
  post_slug TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create an index for better performance
CREATE INDEX idx_post_likes_slug ON post_likes(post_slug);

-- Enable Row Level Security (optional, for better security)
ALTER TABLE post_likes ENABLE ROW LEVEL SECURITY;

-- Create a policy that allows anyone to read and insert likes
CREATE POLICY "Allow public read access" ON post_likes
  FOR SELECT USING (true);

CREATE POLICY "Allow public insert access" ON post_likes
  FOR INSERT WITH CHECK (true);

-- Function to get like count for a post
CREATE OR REPLACE FUNCTION get_post_likes(slug TEXT)
RETURNS INTEGER AS $$
BEGIN
  RETURN (SELECT COUNT(*) FROM post_likes WHERE post_slug = slug);
END;
$$ LANGUAGE plpgsql;