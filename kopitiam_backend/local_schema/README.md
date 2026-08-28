# Local server schema

`user_app_mobile.sql` adalah struktur tabel SQLite untuk salinan lokal dari tab Google Sheet `User_App_Mobile`.

Urutan kolom sumber Google Sheet tetap dipetakan sebagai berikut: No, Kode UIW, Kode UP3, Kode ULP, ULP, Username, Password, Role, Bidang, Tim, Sub-Tim, Akses Menu.

Perbedaannya sengaja penting: kolom `Password` remote tidak disimpan ke lokal. Saat download master pertama kali, server memverifikasi kredensial lewat API online, lalu mengirim data profil tanpa password. Hash + salt password dibuat lokal hanya jika fitur login offline memang diaktifkan. Token sesi lokal juga hanya disimpan sebagai hash.

Mapping saat sinkron:

- `remote_no` <- No
- `kode_uiw` <- Kode UIW
- `kode_up3` <- Kode UP3
- `kode_ulp` <- Kode ULP
- `ulp` <- ULP
- `username` <- Username
- `role` <- Role
- `bidang` <- Bidang
- `tim` <- Tim
- `sub_tim` <- Sub-Tim
- `akses_menu` <- Akses Menu

Catatan: jangan menyalin nilai Password dari Google Sheet ke database lokal. Untuk tahap berikutnya kita perlu memilih salah satu desain login offline: password dimasukkan ulang saat download lalu langsung di-hash lokal, atau aplikasi memakai PIN lokal setelah login online.