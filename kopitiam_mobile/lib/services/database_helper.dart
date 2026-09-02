import 'package:sqflite/sqflite.dart';

/// Skema SQLite tambahan untuk modul WO Inspeksi Gardu.
class DatabaseHelper {
  static const woInsduTable = 'wo_insdu';

  static Future<void> createInsduSchema(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS $woInsduTable (
      id INTEGER PRIMARY KEY AUTOINCREMENT, no TEXT NOT NULL DEFAULT '', kode_wo TEXT NOT NULL UNIQUE, kode_uiw TEXT NOT NULL DEFAULT '', kode_up3 TEXT NOT NULL DEFAULT '', kode_ulp TEXT NOT NULL DEFAULT '', ulp TEXT NOT NULL DEFAULT '', hari TEXT NOT NULL DEFAULT '', tanggal TEXT NOT NULL DEFAULT '', penyulang TEXT NOT NULL DEFAULT '', section TEXT NOT NULL DEFAULT '', nomor_gardu TEXT NOT NULL DEFAULT '', koordinat_gardu TEXT NOT NULL DEFAULT '', lat TEXT NOT NULL DEFAULT '', long TEXT NOT NULL DEFAULT '', jurusan TEXT NOT NULL DEFAULT '',
      beban_utama_r_wbp REAL, beban_utama_s_wbp REAL, beban_utama_t_wbp REAL, beban_jurusan_n_wbp REAL, tegangan_rs_wbp REAL, tegangan_st_wbp REAL, tegangan_rt_wbp REAL, tegangan_rn_wbp REAL, tegangan_sn_wbp REAL, tegangan_tn_wbp REAL,
      beban_utama_r_lwbp REAL, beban_utama_s_lwbp REAL, beban_utama_t_lwbp REAL, beban_jurusan_n_lwbp REAL, tegangan_rs_lwbp REAL, tegangan_st_lwbp REAL, tegangan_rt_lwbp REAL, tegangan_rn_lwbp REAL, tegangan_sn_lwbp REAL, tegangan_tn_lwbp REAL,
      cover_fco_atas TEXT NOT NULL DEFAULT '', cover_fco_bawah TEXT NOT NULL DEFAULT '', cover_bushing_tm TEXT NOT NULL DEFAULT '', cover_bushing_tr TEXT NOT NULL DEFAULT '', cover_arrester TEXT NOT NULL DEFAULT '', jumperan_atas TEXT NOT NULL DEFAULT '', jumperan_bawah TEXT NOT NULL DEFAULT '', waktu_mulai TEXT NOT NULL DEFAULT '', waktu_selesai TEXT NOT NULL DEFAULT '', durasi_pekerjaan TEXT NOT NULL DEFAULT '', status_wo TEXT NOT NULL DEFAULT 'Mulai Pengerjaan', is_dirty INTEGER NOT NULL DEFAULT 0
    )''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_wo_insdu_status ON $woInsduTable(status_wo)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_wo_insdu_dirty ON $woInsduTable(is_dirty)');
  }

  static Future<void> createHarJarSchema(Database db) async {
    // Kept as a no-op compatibility hook; Har Jar is created by the existing migration in prior revisions.
  }
}
