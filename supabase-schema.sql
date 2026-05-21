-- Create tournaments table
CREATE TABLE tournaments (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  is_completed BOOLEAN DEFAULT false,
  last_updated BIGINT DEFAULT EXTRACT(EPOCH FROM NOW()) * 1000
);

-- Create matches table
CREATE TABLE matches (
  id BIGSERIAL PRIMARY KEY,
  display_order INTEGER NOT NULL,
  player_a1_name TEXT NOT NULL,
  player_a2_name TEXT,
  player_b1_name TEXT NOT NULL,
  player_b2_name TEXT,
  score_a INTEGER DEFAULT 0,
  score_b INTEGER DEFAULT 0,
  status INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create rankings table
CREATE TABLE rankings (
  id BIGSERIAL PRIMARY KEY,
  player_id BIGINT NOT NULL,
  player_name TEXT NOT NULL,
  matches_played INTEGER DEFAULT 0,
  wins INTEGER DEFAULT 0,
  total_score INTEGER DEFAULT 0,
  total_lost INTEGER DEFAULT 0,
  net_score INTEGER DEFAULT 0
);

-- Enable Row Level Security (optional, for public read access)
ALTER TABLE tournaments ENABLE ROW LEVEL SECURITY;
ALTER TABLE matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE rankings ENABLE ROW LEVEL SECURITY;

-- Create policies for public read access (since this is a public display app)
CREATE POLICY "Public read access for tournaments" ON tournaments FOR SELECT USING (true);
CREATE POLICY "Public read access for matches" ON matches FOR SELECT USING (true);
CREATE POLICY "Public read access for rankings" ON rankings FOR SELECT USING (true);

-- Insert sample data
INSERT INTO tournaments (name, is_completed, last_updated) VALUES
('周三晚热血六人转', false, 1715400000000);

INSERT INTO matches (display_order, player_a1_name, player_a2_name, player_b1_name, player_b2_name, score_a, score_b, status) VALUES
(0, '张三', '李四', '王五', '赵六', 21, 18, 2),
(1, '王五', '陈七', '李四', '孙八', 15, 21, 2),
(2, '张三', '孙八', '赵六', '陈七', 11, 9, 1),
(3, '李四', '王五', '张三', '孙八', 0, 0, 0);

INSERT INTO rankings (player_id, player_name, matches_played, wins, total_score, total_lost, net_score) VALUES
(2, '李四', 2, 1, 39, 36, 3),
(1, '张三', 1, 1, 21, 18, 3),
(5, '孙八', 1, 1, 21, 15, 6),
(3, '王五', 2, 0, 33, 42, -9);
