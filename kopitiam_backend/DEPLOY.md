# 🤖 Skill AI: Deploy Backend Kopitiam

Checklist deploy backend Kopitiam (Google Apps Script) agar scope Drive, otorisasi, dan deployment tidak terlewat. Ikuti setiap kali ada perubahan di folder `kopitiam_backend`.

## Validasi prasyarat: referensi header setup (pengelola GAS)

Task `3cb7edc9-d6af-40d1-80a9-dd9eae4354bf` memperbaiki pemanggilan header
di `d:\Visual Studio Code\Kopitiam-UID-Babel\kopitiam_backend\Setup.js:64`
agar memakai fungsi existing `temuanSheetHeaders_()`. Target tetap `Inp_Temuan`;
tidak ada perubahan schema, urutan header existing, manifest, atau fitur C4A.

**Status produksi: menunggu validasi pengelola GAS.** Tes Node memakai mock,
bukan bukti setup/deployment produksi berhasil. Jangan membuka Fase 1 sebelum
bukti berikut dikonfirmasi oleh pengelola:

1. Cocokkan project GAS, konfigurasi spreadsheet master/WO/temuan, dan deployment
   yang aktif. Ambil cadangan spreadsheet sebelum menjalankan setup. Catat jumlah
   baris, urutan header, isi dan formula existing untuk perbandingan. Hindari
   pengiriman temuan bersamaan selama pemeriksaan agar hasil dapat dibandingkan.
2. Tinjau diff dan unggah source yang disetujui. Di editor GAS, pastikan setup
   memanggil `temuanSheetHeaders_()` dan fungsi tersebut tersedia. Perbaikan ini
   tidak memerlukan perubahan OAuth scopes; pertahankan manifest repository.
3. Jalankan `setupBackend()` dari editor dengan akun pengelola berizin. Periksa
   **Executions**: eksekusi selesai tanpa `ReferenceError` atau error header.
   Setup juga menyentuh Drive, membuat pepper hanya jika belum ada, memasang
   trigger cleanup bila belum ada, dan menghapus token perangkat kedaluwarsa/rusak;
   ini bukan operasi read-only.
4. Bandingkan data, formula, urutan header dan jumlah baris existing sebelum/sesudah:
   harus tetap sama. Setup hanya mengisi 34 header jika sheet belum ada/kosong.
   Untuk sheet existing, seluruh nama header wajib tersedia (urutan bebas,
   kapitalisasi/spasi tepi diabaikan, kolom tambahan diperbolehkan). Jika kurang,
   **hentikan validasi dan laporkan kolom yang hilang**; jangan kosongkan sheet
   atau menimpa header/data untuk memaksa setup lolos.
5. Jalankan setup sekali lagi: data tetap sama dan trigger
   `bersihkanTokenPerangkatKedaluwarsa` tidak bertambah. Pemeriksaan sheet kosong/
   baru cukup memakai mock lokal atau spreadsheet uji, bukan menghapus produksi.
6. Perbarui deployment existing ke versi source yang disetujui; pertahankan URL.
   Periksa health endpoint sesuai langkah deployment di bawah. Health saja tidak
   membuktikan setup berhasil atau data tetap utuh.
7. Laporkan waktu dan ID eksekusi setup, versi source/deployment, hasil perbandingan
   data, hasil eksekusi ulang dan health, serta persetujuan pengelola pada task.
   Jangan menyertakan token, kredensial atau data pengguna. Task belum tuntas
   end-to-end sampai konfirmasi ini tersedia.

---

## 📋 Informasi Project

| Item | Nilai |
|------|-------|
| **Repo** | `Syahludin/Kopitiam-UID-Babel` |
| **Folder backend** | `kopitiam_backend/` |
| **Script ID** | `1O6NX7eWbfwASndnykE9r9azSzdFMo8ybWIG9adaIFFVQgtN9T7jbph60` |
| **Deployment URL** | `https://script.google.com/macros/s/AKfycbxi45JX9sm_sgeLvXzI6KZsvJAlzaWhjtfT6p2W51vqwvp-TY7gAsXC9PA-Q_HZYp0o3Q/exec` |
| **Akun deployer** | `admin@ulptoboali.com` |
| **Execute as** | Me (akun deployer) |
| **Access** | Anyone (tanpa login Google) |

---

## 🔑 Scope OAuth yang Dibutuhkan

```json
"oauthScopes": [
  "https://www.googleapis.com/auth/spreadsheets",
  "https://www.googleapis.com/auth/drive",
  "https://www.googleapis.com/auth/script.scriptapp"
]
```

| Scope | Dibutuhkan oleh |
|-------|----------------|
| `spreadsheets` | Seluruh operasi baca/tulis ke Google Sheets (login, master data, WO, Temuan) |
| `drive` | `folderPath_()` dan `saveImage_()` untuk membuat folder dan upload foto Temuan ke Drive |
| `script.scriptapp` | `setupBackend()` untuk memasang trigger pembersihan token perangkat |

---

## 🚀 Langkah Deploy

### Langkah 1: Pull dan masuk folder backend

```powershell
git pull origin main
cd kopitiam_backend
```

### Langkah 2: Login clasp (jika perlu)

Jalankan hanya jika `clasp push` gagal dengan `invalid_grant` atau `invalid_rapt`:

```powershell
npx clasp login
```

Browser akan terbuka, pilih akun `admin@ulptoboali.com`, izinkan akses.

### Langkah 3: Push ke Apps Script

```powershell
npx clasp push --force
```

> **Penting:** Flag `--force` memastikan semua file termasuk `appsscript.json` ditimpa di project Apps Script.

File `.claspignore` harus mengecualikan:
```
test/**
local_schema/**
package.json
package-lock.json
README.md
.clasp.json
```

Tanpa ini, Apps Script akan error karena `require()` dari file test.

### Langkah 4: Verifikasi manifest di editor

Buka editor Apps Script:

```powershell
npx clasp open-script
```

Di editor:
1. Klik **Project Settings** (ikon gear)
2. Centang **"Show appsscript.json manifest file in editor"**
3. Kembali ke **Editor**, buka file `appsscript.json`
4. Pastikan `oauthScopes` memuat ketiga scope di atas
5. Jika berbeda, **edit langsung di editor**, lalu **Ctrl+S**

> ⚠️ `clasp push` kadang gagal menimpa manifest tanpa pesan error. **Selalu verifikasi secara visual.**

### Langkah 5: Paksa re-otorisasi

> Wajib dilakukan setiap kali scope berubah. Tanpa ini, Google tetap menggunakan izin lama yang tidak mencakup scope baru.

1. Buka **https://myaccount.google.com/permissions**
2. Cari project Kopitiam Apps Script, klik **Remove Access**
3. Kembali ke editor Apps Script
4. Pilih fungsi `testDriveAccess` atau `setupBackend` di dropdown
5. Klik **Run**
6. Muncul dialog **"Authorization required"**
7. Klik **Review Permissions** → pilih `admin@ulptoboali.com` → **Allow**

> Jika dialog izin **tidak muncul**, berarti manifest belum terupdate. Kembali ke Langkah 4.

### Langkah 6: Verifikasi Drive access

Jalankan `testDriveAccess` dari editor. Execution Log harus menampilkan:

```
Drive root: Drive Saya
Owner: admin@ulptoboali.com
Drive access OK ✓
```

Untuk tes lengkap (folder + upload foto + sheet Temuan), jalankan `testSyncTemuanDummy`:

```
=== TEST 1: Drive access ===
Root folder: Drive Saya ✓
=== TEST 2: Folder creation ===
Folder dibuat/ditemukan: TEST_DUMMY ✓
=== TEST 3: File upload ===
File dibuat: test_dummy.jpg ✓
=== TEST 4: Spreadsheet Inp_Temuan ===
Sheet: Inp_Temuan, baris: ... ✓
=== TEST 5: buildFindingPath_ ===
Path: Kopitiam/Rekap Temuan Inspeksi/... ✓
Folder awal Kopitiam ✓
=== SEMUA TEST BERHASIL ===
```

### Langkah 7: Deploy versi baru

1. Di editor, klik **Deploy → Manage deployments**
2. Klik ikon **Edit** (pensil) pada deployment yang ada
3. Pilih **Version: New version**
4. Klik **Deploy**

> URL `/exec` tetap sama. **Tanpa langkah ini, endpoint masih menjalankan kode lama.**

### Langkah 8: Verifikasi endpoint

Buka di browser:

```
https://script.google.com/macros/s/AKfycbxi45JX9sm_sgeLvXzI6KZsvJAlzaWhjtfT6p2W51vqwvp-TY7gAsXC9PA-Q_HZYp0o3Q/exec?action=health
```

Harus menjawab:

```json
{"success":true,"service":"Kopitiam API","version":"3.0.0"}
```

---

## 📱 Apakah perlu release APK?

**Tidak.** Selama deployment ID dan URL `/exec` tidak berubah, APK Flutter yang sudah terinstal tetap bekerja tanpa rebuild.

---

## 🔧 Troubleshooting

| Gejala | Penyebab | Solusi |
|--------|----------|--------|
| `invalid_grant` / `invalid_rapt` saat `clasp push` | Token clasp expired | `npx clasp login` |
| `Script function not found: doGet` | File tidak masuk project | Cek `.claspignore`, pastikan `Code.js` tidak dikecualikan |
| `permission to call DriveApp.Folder.createFolder` | Scope `drive` belum authorized | Langkah 4 + 5 |
| Fungsi jalan di editor, gagal dari `/exec` | Deployment belum diupdate | Langkah 7 |
| `clasp push` sukses tapi manifest tidak berubah | Bug clasp | Edit `appsscript.json` langsung di editor (Langkah 4) |
| Health check masih versi lama | Deployment belum diupdate | Langkah 7 |
| WO sync berhasil tapi Temuan gagal | Temuan pakai `DriveApp`, WO tidak | Pastikan scope `drive` ter-authorize (Langkah 5-6) |

---

## 📂 Struktur File Backend

| File | Fungsi |
|------|--------|
| `Code.js` | Router utama (`doGet`, `doPost`), semua endpoint API |
| `Setup.js` | `setupBackend()`, validasi sheet, trigger pembersihan token |
| `IdempotentUpload.js` | Upload foto idempoten dengan SHA-256, rollback otomatis |
| `SecurityValidation.js` | Validasi JPEG, koordinat, dan master data Temuan |
| `RuntimeGuards.js` | Rate limit, expiry token, status akun |
| `ZZ_RuntimeIntegration.js` | Penghubung guard ke router produksi |
| `TestDummy.js` | Fungsi test Drive access dan sinkron dummy |
| `appsscript.json` | Manifest: scope, timezone, deployment config |
| `.claspignore` | File yang dikecualikan dari push |
| `.clasp.json` | Script ID dan konfigurasi clasp |

---

## 📝 Catatan Penting

- Deployment yang sudah ada mempertahankan URL `/exec` yang sama selama kamu **edit** deployment, bukan membuat deployment baru.
- `Execute as: Me` berarti script berjalan dengan akun `admin@ulptoboali.com`. File Drive yang dibuat masuk ke Drive akun tersebut.
- Setiap kali menambah scope baru ke manifest, **selalu lakukan Langkah 5** (hapus akses lama, picu ulang otorisasi).
- Folder foto Temuan disimpan di `Kopitiam/Rekap Temuan Inspeksi/<ULP>/<Object>/<Tahun>/<Bulan>/<Tanggal>/<Kode WO>/<Kode Temuan>/`.
- `testSyncTemuanDummy` otomatis membersihkan folder dan file test setelah selesai.
