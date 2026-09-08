# Implementasi Har: pekerjaan dan material

Dokumen tambahan untuk [PRD Har](PRD_HAR.md). Kontrak terbaru dari diskusi pengguna mengungguli rancangan awal yang berbeda. Tidak ada merge, deploy, perubahan Spreadsheet, atau implementasi C4A Fase 3 dari perubahan ini.

## Alur yang diminta

1. Beranda: Download WO sesuai Jenis WO dan penugasan akun.
2. Menu Work Order: daftar WO lokal menggunakan pola card inspeksi (padding 15, radius 16, warna status) dan KopitiamTheme.
3. Klik card yang belum dimulai: dialog berisi Kode WO dan pilihan Tidak/Ya. Tidak tidak mengubah data. Ya mengisi Waktu Mulai sekali dan Status WO = Progress Pekerjaan; tetap di daftar.
4. Klik ulang card: tab Detail WO dan Pekerjaan. FAB + pekerjaan hanya di tab Pekerjaan, disembunyikan setelah WO Selesai.
5. Form pekerjaan: tab Pekerjaan (Uraian Pekerjaan, Jumlah, Set) dan tab Material. Set dipertahankan sebagai field teks karena lookup/semantik master pekerjaan belum ditetapkan.
6. Tab Material: + menambah satu baris input Nama Material, Jumlah Material (satuan dari lookup), Kepemilikan. Tidak ada input Satuan. Material opsional.
7. Simpan pekerjaan menyimpan pekerjaan dan material dalam satu transaksi lokal. Tidak menyelesaikan header WO.
8. Detail WO: ambil Foto Sesudah melalui kamera landscape, catatan opsional, Simpan Selesai mengisi User Input dari username, Waktu Selesai dan Status WO Selesai. Durasi tidak digunakan. Header selesai read-only.
9. Sinkron dari Beranda mengirim tiap paket WO; konfirmasi server berdasarkan Kode WO, bukan jumlah saja. Data lokal tetap ada, gagal sinkron dapat dicoba ulang.

## Sumber dan relasi

Header: WO_Har_Jar dan WO_Har_Du. Pekerjaan: Pekerjaan_WO_Har. Material: Material_WO_Har. Spreadsheet transaksi: `1NYLuEIxOz8Hk4INvv8q6wq_W5CCOgfQUn7ffDgyDGy8`.

Master_Material dari spreadsheet `1PuHONGQ8ZOBQRutk9RR5-ZjFcrqW3hWfBYllQu4RUMo`: No, Kode Material, Nama Material, Satuan Material, Status Baris. Pemilihan lokal berdasarkan Kode Material; nilai Material pada sheet detail adalah Nama Material. Backend memeriksa nama unik dan mencocokkan Satuan Material. Nama atau kode ambigu ditolak, tidak ditebak. Nilai Status Baris yang eksplisit nonaktif/hapus/false/0 dikecualikan; kosakata lengkap Status Baris belum diberikan pengguna. Kepemilikan memakai pilihan existing PLN, Mitra, Bongkaran.

Kode Temuan tetap parent permanen. Kode WO baru milik Koordinator. Pekerjaan memakai Kode Pekerjaan; material memakai Kode Penggunaan Material dan Kode Pekerjaan. ID PKJ/MAT menggunakan 128-bit acak dan tidak berubah saat retry. Jenis WO cukup sebagai pembeda; tidak menambah Jenis Modul. Pada Material_WO_Har, alias header Kode Pekerjaan WO Har dan Kode WO Har diterima untuk kompatibilitas struktur awal.

Data inherited diturunkan ulang dari header server sebelum menulis detail. Koordinat, Lat, Long dan Folder Path parent tidak ditimpa. Link Foto Sesudah berasal dari upload server. Penutupan WO inspeksi berdasarkan penyelesaian section inspeksi, bukan menunggu WO tindak lanjut: tidak ada auto-close parent dalam fitur ini.

## Kontrak penyimpanan

SQLite menggunakan tabel tambahan har_execution_v2 dengan primary key (owner,jenis_wo,kode_wo), payload header/jobs/materials, nomor revisi dan status dirty/error. Tidak menghapus atau mengubah tabel lama. WO lama yang belum sinkron harus diselesaikan dengan versi lama sebelum rollout; belum ada migrasi otomatis payload legacy. Download baru dimulai dari Beranda. Download tidak menimpa progres atau antrean lokal. Pergantian akun tidak menampilkan antrean akun lain.

Endpoint existing getWoHarJar/getWoHarDu memvalidasi ULP dan Tim Eksekusi (cocok username, tim, atau subTim sesi). Endpoint sync menggunakan schemaVersion:2 untuk jalur baru; payload lama masih ditangani handler legacy. Format Tim Eksekusi lain perlu pemetaan eksplisit, tidak dicocokkan secara substring.

Backend memvalidasi satu paket sebelum menulis, meng-upsert pekerjaan/material berdasarkan ID, menggunakan upload foto idempoten existing, lalu menulis status header terakhir. Google Sheets tidak menyediakan transaksi lintas sheet; kegagalan parsial tidak diberi ACK dan retry melengkapi data tanpa membuat ID baru. Formula/kolom ekstra tidak ditimpa saat update. Sheet dan header harus disiapkan operator sesuai struktur pengguna; tidak dibuat atau dihapus otomatis.

## Pengujian

Tes tambahan tidak mengganti tes existing. Backend: validasi, isolasi akun, lookup satuan, kedua Jenis WO, replay, kegagalan parsial, parent immutable dan read-only setelah selesai. Flutter: model, resolver akses, dialog konfirmasi, FAB khusus tab pekerjaan dan input material. SQLite native, kamera/GPS fisik serta integrasi deployment Google Sheets tetap perlu acceptance pada perangkat dan deployment pengguna.
