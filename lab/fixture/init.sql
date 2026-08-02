CREATE TABLE IF NOT EXISTS document_link (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    external_id text NOT NULL UNIQUE,
    checksum_sha256 text NOT NULL CHECK (checksum_sha256 ~ '^[0-9a-f]{64}$')
);

CREATE TABLE IF NOT EXISTS asset (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    path text NOT NULL UNIQUE,
    checksum_sha256 text NOT NULL CHECK (checksum_sha256 ~ '^[0-9a-f]{64}$')
);

COMMENT ON TABLE document_link IS
    'Laboratory fixture only. Not the production Core data model.';

COMMENT ON TABLE asset IS
    'Laboratory fixture only. Not the production Core data model.';

