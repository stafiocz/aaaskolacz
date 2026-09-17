CREATE TABLE school_grades (
  id smallint PRIMARY KEY CHECK (id BETWEEN 1 AND 99),
  name text NOT NULL CHECK (length(name) BETWEEN 1 AND 100),
  sort_order integer NOT NULL DEFAULT 0,
  active boolean NOT NULL DEFAULT true
);
CREATE TABLE school_subjects (
  id text PRIMARY KEY CHECK (id ~ '^[a-z][a-z0-9_-]{0,63}$'),
  slug text NOT NULL UNIQUE CHECK (slug ~ '^[a-z][a-z0-9-]{0,63}$'),
  name text NOT NULL CHECK (length(name) BETWEEN 1 AND 100),
  kind text NOT NULL CHECK (kind IN ('math', 'vocabulary')),
  answer_language text NOT NULL DEFAULT '',
  active boolean NOT NULL DEFAULT true
);
CREATE TABLE school_courses (
  grade smallint NOT NULL REFERENCES school_grades(id),
  subject text NOT NULL REFERENCES school_subjects(id),
  description text NOT NULL DEFAULT '',
  source_title text NOT NULL DEFAULT '',
  max_digits smallint NOT NULL DEFAULT 7 CHECK (max_digits BETWEEN 1 AND 7),
  sort_order integer NOT NULL DEFAULT 0,
  active boolean NOT NULL DEFAULT true,
  PRIMARY KEY (grade, subject)
);
CREATE TABLE practice_items (
  id text PRIMARY KEY CHECK (id ~ '^[a-zA-Z0-9][a-zA-Z0-9_-]{0,127}$'),
  grade smallint NOT NULL,
  subject text NOT NULL,
  data jsonb NOT NULL CHECK (jsonb_typeof(data) = 'object'),
  active boolean NOT NULL DEFAULT true,
  FOREIGN KEY (grade, subject) REFERENCES school_courses(grade, subject)
);
CREATE INDEX practice_items_course ON practice_items(grade, subject) WHERE active;
