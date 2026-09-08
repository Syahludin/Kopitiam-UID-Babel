# Validasi C4A Fase 1 — 8 September 2026

## Batas implementasi

Task 1–15 dikerjakan berurutan sesuai `d:\Visual Studio Code\Kopitiam-UID-Babel\docs\TASKS.md`. Prasyarat `3cb7edc9-d6af-40d1-80a9-dd9eae4354bf` terkonfirmasi `done` melalui CLI sebelum implementasi. Task `[RETIRED]` tidak diubah/dibangun. `task next` masih menyajikan task retired, sehingga task aktif diambil satu per satu melalui referensi sesuai urutan dokumen.

Konfirmasi CLI `task list --all --json` pada 13:49 WIB: **15 task aktif Fase 1, 15 done**. Semua task Fase 2 dan Fase 3 tetap `todo`.

Tidak ada deploy GAS, perubahan spreadsheet, endpoint baru, WO dummy, beranda/status/sinkronisasi C4A, ataupun implementasi akses peran Fase 3. Target kontrak tetap `Inp_Temuan`; `Kode WO` dan `Jenis WO` kosong. Final summary sync NgodingPakeAI tidak dijalankan karena keseluruhan plan belum selesai.

## Hasil per task

| Task | Hasil |
| --- | --- |
| 1 | `Jenis Object` wajib dipilih Jaringan/Gardu; C4A tidak terkunci subTim WO. |
| 2 | UID/Super User memilih UP3→ULP; UP3 memilih ULP sendiri; ULP langsung. Label §8.7, nilai kode numerik. |
| 3 | Penyulang sesuai ULP, keypoint sesuai ULP+Penyulang, Section Akhir mengecualikan Awal, gabungan `Awal - Akhir`, Segmen manual. |
| 4 | Gardu sesuai ULP; Penyulang, PTS/LBS→Section, lat/long diisi dari satu baris master. Presisi desimal tidak dipotong/dibalik. Master ambigu/koordinat invalid ditahan. |
| 5 | Temuan hanya dari objek sesuai cabang, metadata objek kosong/ambigu tidak diloloskan. |
| 6 | Constructor `TemuanFormScreen.c4a(sesi: ...)` mengembangkan form existing dalam satu scroll, tanpa layar pemilihan/ringkasan terpisah. |
| 7 | Blok “Aset yang Dinilai” satu baris aset, sebelum detail temuan; berubah mengikuti pilihan. |
| 8 | Kode UIW/UP3/ULP, nama ULP dan username berasal dari unit berlaku/akun login; identitas tidak lengkap/ambigu ditahan. |
| 9 | Format `PEG-<ULP><YYMMDD><NNN>.TO-<NNN>` ditetapkan saat simpan, bukan saat membuka form atau mengambil foto. |
| 10 | Nomor pertama dari maksimum nomor tersimpan per ULP+Penyulang+hari; hari baru mulai 001. |
| 11 | TO dari maksimum per ULP lintas hari/Penyulang, satu temuan satu TO. Pembacaan nomor dan insert berada dalam satu transaksi SQLite, tanpa replace. |
| 12 | Filter Tier+Object bersamaan, perubahan Tier mereset temuan/ROW/foto yang tidak berlaku. |
| 13 | GPS jaringan manual saat diklik, menggunakan service presisi/anti-mock existing; C4A menolak fix tidak locked atau akurasi >5 m. Hasil GPS dari konteks aset lama diabaikan. |
| 14 | ROW memakai batas inklusif `tinggi >= jarak * sqrt(2)` → Mayor, lalu formula existing; non-ROW lookup `Master_Temuan` existing. Formula WO tidak diubah. |
| 15 | Waktu/hari/tanggal/folder otomatis saat simpan; dua JPEG landscape berbeda wajib, validasi ukuran/format/metadata/ROW; watermark dengan kode final; file disalin permanen; error simpan dapat diperbaiki tanpa kehilangan form. |

## Integrasi yang sengaja ditunda

- Form **belum ditautkan ke menu produksi**. Fase 2 harus membuka constructor C4A melalui FAB `+` beranda daftar temuan lokal, mengikuti pola `TemuanTab._add`, dan memuat ulang daftar ketika hasil navigasi `true`. FAB dalam tes hanyalah harness, bukan beranda baru.
- Temuan C4A tersimpan di tabel `temuan_inspeksi` existing. Sinkronisasi WO existing mengecualikan `kode_wo = ''` agar tidak mengirim C4A ke endpoint WO sebelum Fase 2.
- `Link Foto` dan `Link Foto Sekitaran Tiang` tetap kosong saat offline; tidak dibuat URL palsu. Pengisian link Drive adalah urusan pengiriman Fase 2.
- Folder C4A memakai pola existing tanpa segmen WO: `Kopitiam/Rekap Temuan Inspeksi/<ULP>/<Object>/<tahun>/<MM. Bulan>/<DD>/<Kode Temuan>/`.
- Backend master hanya mengirim baris akun login. Referensi unit publik §8.7 melengkapi pilihan UID/UP3 tanpa membuka data akun lain; Kode UIW tetap dari akun/master. `Master_Temuan` backend dapat difilter subTim; cache harus memuat cabang yang dibutuhkan. Dropdown kosong ditahan, bukan diganti data tiruan.
- Counter atomik berlaku pada **satu database perangkat**, bukan lintas perangkat offline. Rekonsiliasi multi-perangkat/idempotensi pusat masih Fase 2. Jangan menghapus riwayat C4A saat sinkronisasi karena nomor memakai maksimum riwayat lokal. Counter >999 ditolak, tidak diputar ulang.

## Verifikasi

Dijalankan dari `d:\Visual Studio Code\Kopitiam-UID-Babel\kopitiam_mobile`:

- `flutter test --reporter expanded`: **59/59 lulus** (23 tes tambahan; baseline awal 35 lulus/1 gagal).
- Baseline gagal pada tes source redirect API karena penanda akhir blok sudah usang. Penanda diperbaiki menjadi `return contentResponse;`; assertion larangan payload/body/Authorization tetap dipertahankan, kode API tidak diubah.
- Analisis terarah seluruh Dart yang berubah/baru: **No issues found**, exit 0.
- `flutter analyze --no-pub`: **8 info existing**, tanpa error/warning; exit 1 karena info. Lokasi di form tindak lanjut, temuan_tab, wo_summary_card, wo_row_form, komentar wo_insjar_repository; bukan kode C4A baru.
- Tes widget menguji alur FAB→form→pilih aset→detail→GPS/foto→simpan pada viewport 390×844, perubahan unit/Tier, error simpan dan jalur WO existing.
- Tes repository menjalankan repository dan watermark/file foto asli dengan double transaksi database serta mock direktori perangkat. Ini **bukan** uji SQLite native atau kamera/GPS fisik.

Dijalankan dari `d:\Visual Studio Code\Kopitiam-UID-Babel\kopitiam_backend`:

- `node --test test/setup.test.js`: **10/10 lulus**, exit 0.
- `npm run check` dan `node --check TemuanSheetHelpers.js`: exit 0.
- `npm test`: **57/57 lulus**, exit 0.
- `git diff --check` dari root: bersih.

Tidak ada perangkat Android/iOS tersambung (hanya Windows/Chrome/Edge). Uji kamera, izin GPS, SQLite native, dan acceptance produksi tetap memerlukan perangkat/admin.

Build awal `flutter build apk --debug` berhasil (Gradle 633,8 detik); **rebuild final berhasil, exit 0**, Gradle 78,3 detik. Output CLI: `Built build\app\outputs\flutter-apk\app-debug.apk`. Terdapat peringatan Java native access dan source/target Java 8 dari tooling/plugin. Cache Kotlin build diabaikan melalui gitignore Android.

**Berhenti setelah Fase 1. Task 16+ tidak dimulai tanpa persetujuan.**