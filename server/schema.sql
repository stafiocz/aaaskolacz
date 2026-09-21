CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY,
  google_sub text NOT NULL UNIQUE,
  name text NOT NULL,
  email text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS sessions (
  token_hash text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  csrf text NOT NULL,
  expires_at timestamptz NOT NULL
);
CREATE INDEX IF NOT EXISTS sessions_expiry ON sessions(expires_at);
CREATE TABLE IF NOT EXISTS mobile_login_codes (
  code_hash text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  challenge text NOT NULL,
  expires_at timestamptz NOT NULL
);
CREATE TABLE IF NOT EXISTS exercises (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  id uuid NOT NULL,
  subject text NOT NULL CHECK (subject IN ('math', 'english')),
  grade smallint NOT NULL,
  completed boolean NOT NULL DEFAULT false,
  PRIMARY KEY (user_id, id),
  CHECK ((subject = 'math' AND grade IN (3, 5)) OR
         (subject = 'english' AND grade IN (5, 7)))
);
CREATE TABLE IF NOT EXISTS attempts (
  user_id uuid NOT NULL,
  id uuid NOT NULL,
  exercise_id uuid NOT NULL,
  correct boolean NOT NULL,
  completed boolean NOT NULL CHECK (NOT completed OR correct),
  answered_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, id),
  FOREIGN KEY (user_id, exercise_id) REFERENCES exercises(user_id, id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS attempts_history ON attempts(user_id, answered_at);
