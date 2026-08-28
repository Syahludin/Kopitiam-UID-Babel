CREATE TABLE IF NOT EXISTS wo_insjar (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  no TEXT NOT NULL DEFAULT '',
  kode_wo TEXT NOT NULL UNIQUE,
  kode_uiw TEXT NOT NULL DEFAULT '',
  kode_up3 TEXT NOT NULL DEFAULT '',
  kode_ulp TEXT NOT NULL DEFAULT '',
  ulp TEXT NOT NULL DEFAULT '',
  hari TEXT NOT NULL DEFAULT '',
  tanggal TEXT NOT NULL DEFAULT '',
  penyulang TEXT NOT NULL DEFAULT '',
  section_awal TEXT NOT NULL DEFAULT '',
  section_akhir TEXT NOT NULL DEFAULT '',
  section TEXT NOT NULL DEFAULT '',
  koordinat_awal TEXT NOT NULL DEFAULT '',
  koordinat_akhir TEXT NOT NULL DEFAULT '',
  realisasi_kms REAL,
  waktu_mulai TEXT NOT NULL DEFAULT '',
  waktu_selesai TEXT NOT NULL DEFAULT '',
  durasi_pekerjaan TEXT NOT NULL DEFAULT '',
  status_wo TEXT NOT NULL DEFAULT '',
  synced_at TEXT NOT NULL DEFAULT '',
  is_dirty INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_wo_insjar_tanggal ON wo_insjar(tanggal);
CREATE INDEX IF NOT EXISTS idx_wo_insjar_status ON wo_insjar(status_wo);
CREATE INDEX IF NOT EXISTS idx_wo_insjar_penyulang ON wo_insjar(penyulang);
