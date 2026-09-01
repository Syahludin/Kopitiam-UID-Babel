import 'package:sqflite/sqflite.dart';

/// Skema SQLite offline-first untuk modul WO Har Jar.
class DatabaseHelper {
  static const woHarJarTable = 'wo_har_jar';
  static const woMaterialHarJarTable = 'wo_material_har_jar';

  static Future<void> createHarJarSchema(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS $woHarJarTable (
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
      section TEXT NOT NULL DEFAULT '',
      segmen TEXT NOT NULL DEFAULT '',
      kode_temuan TEXT NOT NULL DEFAULT '',
      kode_wo_inspeksi TEXT NOT NULL DEFAULT '',
      jenis_object TEXT NOT NULL DEFAULT '',
      tier TEXT NOT NULL DEFAULT '',
      temuan TEXT NOT NULL DEFAULT '',
      prioritas TEXT NOT NULL DEFAULT '',
      pekerjaan TEXT NOT NULL DEFAULT '',
      jenis_wo TEXT NOT NULL DEFAULT '',
      koordinat TEXT NOT NULL DEFAULT '',
      lat REAL,
      long REAL,
      foto_temuan TEXT NOT NULL DEFAULT '',
      link_foto_temuan TEXT NOT NULL DEFAULT '',
      foto_tiang_sekitar TEXT NOT NULL DEFAULT '',
      link_foto_tiang_sekitar TEXT NOT NULL DEFAULT '',
      foto_sesudah TEXT NOT NULL DEFAULT '',
      link_foto_sesudah TEXT NOT NULL DEFAULT '',
      catatan_petugas TEXT NOT NULL DEFAULT '',
      tim_eksekusi TEXT NOT NULL DEFAULT '',
      tanggal_penugasan TEXT NOT NULL DEFAULT '',
      catatan_koordinator TEXT NOT NULL DEFAULT '',
      nama_koordinator TEXT NOT NULL DEFAULT '',
      status_wo TEXT NOT NULL DEFAULT 'Menunggu',
      user_input TEXT NOT NULL DEFAULT '',
      waktu_input TEXT NOT NULL DEFAULT '',
      waktu_realisasi TEXT NOT NULL DEFAULT '',
      folder_path TEXT NOT NULL DEFAULT '',
      is_synced INTEGER NOT NULL DEFAULT 0
    )''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_wo_har_jar_status ON $woHarJarTable(status_wo)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_wo_har_jar_synced ON $woHarJarTable(is_synced)',
    );
    await db.execute('''CREATE TABLE IF NOT EXISTS $woMaterialHarJarTable (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      kode_penggunaan_material TEXT NOT NULL UNIQUE,
      kode_wo TEXT NOT NULL,
      material TEXT NOT NULL DEFAULT '',
      jumlah REAL NOT NULL DEFAULT 0,
      satuan TEXT NOT NULL DEFAULT '',
      kepemilikan TEXT NOT NULL DEFAULT '',
      keterangan TEXT NOT NULL DEFAULT '',
      user_input TEXT NOT NULL DEFAULT '',
      waktu_input TEXT NOT NULL DEFAULT '',
      is_synced INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (kode_wo) REFERENCES $woHarJarTable (kode_wo) ON DELETE CASCADE
    )''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_wo_material_kode_wo ON $woMaterialHarJarTable(kode_wo)',
    );
  }
}
