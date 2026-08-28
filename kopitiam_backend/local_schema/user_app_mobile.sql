-- SiManDist local server schema
-- Source remote: Google Sheet tab User_App_Mobile
-- Password plaintext MUST NOT be copied into this local table.

CREATE TABLE IF NOT EXISTS user_app_mobile (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  remote_no TEXT NOT NULL,
  kode_uiw TEXT NOT NULL DEFAULT '',
  kode_up3 TEXT NOT NULL DEFAULT '',
  kode_ulp TEXT NOT NULL DEFAULT '',
  ulp TEXT NOT NULL DEFAULT '',
  username TEXT NOT NULL COLLATE NOCASE,
  password_hash TEXT NOT NULL,
  password_salt TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT '',
  bidang TEXT NOT NULL DEFAULT '',
  tim TEXT NOT NULL DEFAULT '',
  sub_tim TEXT NOT NULL DEFAULT '',
  akses_menu TEXT NOT NULL DEFAULT '',
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
  source_updated_at TEXT,
  synced_at TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE (username)
);

CREATE INDEX IF NOT EXISTS idx_user_app_mobile_username
  ON user_app_mobile (username COLLATE NOCASE);
CREATE INDEX IF NOT EXISTS idx_user_app_mobile_ulp
  ON user_app_mobile (kode_ulp, ulp);
CREATE INDEX IF NOT EXISTS idx_user_app_mobile_active
  ON user_app_mobile (is_active);

-- Token lokal tidak menyimpan password atau token mentah.
CREATE TABLE IF NOT EXISTS local_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES user_app_mobile(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,
  device_id TEXT NOT NULL DEFAULT '',
  expires_at TEXT,
  revoked_at TEXT,
  created_at TEXT NOT NULL,
  last_seen_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_local_sessions_token
  ON local_sessions (token_hash);
CREATE INDEX IF NOT EXISTS idx_local_sessions_user
  ON local_sessions (user_id);

-- Catatan sync master data.
CREATE TABLE IF NOT EXISTS sync_metadata (
  key TEXT PRIMARY KEY,
  remote_revision TEXT NOT NULL DEFAULT '',
  synced_at TEXT,
  row_count INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'idle',
  error_message TEXT NOT NULL DEFAULT ''
);

INSERT OR IGNORE INTO sync_metadata(key, status)
VALUES ('User_App_Mobile', 'idle');
