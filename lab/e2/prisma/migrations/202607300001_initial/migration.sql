CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS unaccent;

CREATE TABLE objects (
  id text PRIMARY KEY,
  kind text NOT NULL,
  title text NOT NULL,
  version integer NOT NULL DEFAULT 1,
  search_vector tsvector,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE field_definitions (
  id text PRIMARY KEY,
  key text NOT NULL,
  value_type text NOT NULL,
  CONSTRAINT field_definitions_value_type_check
    CHECK (value_type IN ('text', 'number', 'boolean'))
);

CREATE UNIQUE INDEX field_definitions_key_idx
  ON field_definitions (key);

CREATE TABLE object_field_values (
  object_id text NOT NULL REFERENCES objects(id) ON DELETE CASCADE,
  definition_id text NOT NULL
    REFERENCES field_definitions(id) ON DELETE RESTRICT,
  value jsonb NOT NULL,
  CONSTRAINT object_field_values_pk
    PRIMARY KEY (object_id, definition_id)
);

CREATE TABLE tags (
  id text PRIMARY KEY,
  name text NOT NULL
);

CREATE UNIQUE INDEX tags_name_idx ON tags (name);

CREATE TABLE object_tags (
  object_id text NOT NULL REFERENCES objects(id) ON DELETE CASCADE,
  tag_id text NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  CONSTRAINT object_tags_pk PRIMARY KEY (object_id, tag_id)
);

CREATE TABLE audit_entries (
  id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  object_id text NOT NULL REFERENCES objects(id) ON DELETE CASCADE,
  action text NOT NULL,
  diff jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX objects_search_vector_gin_idx
  ON objects USING gin (search_vector);

CREATE INDEX objects_title_trgm_idx
  ON objects USING gin (title gin_trgm_ops);
