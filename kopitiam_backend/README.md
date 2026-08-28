# SiManDist Backend

Backend Google Apps Script untuk Flutter dengan penyimpanan Google Sheets.

## Konfigurasi

1. Buat Google Sheet kosong.
2. Buat project Apps Script, lalu salin file `Code.js`, `Setup.js`, dan `appsscript.json`, atau gunakan `clasp`.
3. Buka **Project Settings > Script Properties** dan tambahkan `SPREADSHEET_ID` berisi ID Google Sheet. Jangan menaruh ID atau rahasia di source code.
4. Jalankan `setupBackend()` sekali dari editor dan berikan izin.
5. Buat akun pertama sementara melalui editor: `buatUserPertama('admin', 'password-minimal-8-karakter', 'email@contoh.com')`.
6. Deploy sebagai Web app: execute as **Me**, access **Anyone**. Simpan URL `/exec`.
7. Tes URL `/exec?action=health`.

## API

Semua autentikasi selain health memakai `POST` dengan header `Content-Type: application/json`.

Login:
```json
{"action":"login","username":"admin","password":"password"}
```

Cek sesi:
```json
{"action":"cekSesi","token":"TOKEN"}
```

Logout:
```json
{"action":"logout","token":"TOKEN"}
```

Password tidak disimpan sebagai teks biasa. Token mentah hanya dikirim ke aplikasi, sedangkan Google Sheet menyimpan hash token. Masa sesi default 30 hari.
