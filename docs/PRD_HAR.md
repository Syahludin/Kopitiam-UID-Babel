# PRD Har - WO Har Jar dan WO Har Du

> Dokumen ini diperbarui bertahap. Bagian yang sudah disepakati dikunci sebagai keputusan; bagian berikutnya ditambahkan setelah review.

## 0. Sumber spreadsheet

Struktur sheet sumber untuk WO Har berada pada [Spreadsheet WO Har](https://docs.google.com/spreadsheets/d/1NYLuEIxOz8Hk4INvv8q6wq_W5CCOgfQUn7ffDgyDGy8/edit?gid=1534488256#gid=1534488256).

Sheet yang menjadi acuan:

- `WO_Har_Jar`
- `WO_Har_Du`

Referensi ini dipakai untuk mencocokkan struktur header, lineage, dan rancangan detail pekerjaan/material. Data di spreadsheet tidak diubah oleh PRD ini.

## 1. Keputusan model data

Satu baris pada `WO_Har_Jar` atau `WO_Har_Du` merepresentasikan **satu Work Order eksekusi**, bukan satu kegiatan dan bukan satu penggunaan material. Karena satu WO dapat memiliki banyak kegiatan dan setiap kegiatan dapat memakai banyak material, kegiatan serta material tidak boleh dipaksakan menjadi kolom berulang pada baris WO.

Model yang dipakai:

- **Header WO (1 baris):** `WO_Har_Jar` atau `WO_Har_Du`.
- **Detail pekerjaan (0..n baris):** satu tabel detail pekerjaan Har.
- **Detail material (0..n baris):** satu tabel detail material Har.
- Relasi header ke detail menggunakan `Kode WO`.
- Relasi pekerjaan ke material menggunakan `Kode Pekerjaan`.
- Relasi seluruh WO tindak lanjut ke temuan asal menggunakan `Kode Temuan`.
- `Jenis WO` menjadi discriminator bisnis; nilainya otomatis dari sumber header (`WO Har Jar`, `WO Har Du`, atau `WO ROW`). Tidak ada kolom `Jenis Modul` tambahan.

Dengan model ini, satu WO tetap satu baris, tetapi petugas dapat mencatat banyak pekerjaan dan banyak material tanpa menambah kolom dinamis seperti `Pekerjaan 1`, `Pekerjaan 2`, atau `Material 1`.

## 2. Data lineage yang disepakati

```text
WO_Ins_Jar / WO_Ins_Du
  -> petugas inspeksi mengerjakan WO
  -> temuan disimpan ke Inp_Temuan
  -> Team Leader memverifikasi temuan
  -> Koordinator memilih tim eksekusi
  -> sistem membuat Kode WO eksekusi baru
  -> data diteruskan ke WO_ROW / WO_Har_Jar / WO_Har_Du
  -> petugas Har mengunduh WO
  -> klik card: Status WO = Progress Pekerjaan, Waktu Mulai terisi otomatis
  -> petugas mengisi satu atau lebih pekerjaan dan material yang digunakan
  -> petugas mengambil Foto Sesudah dan menyimpan
  -> Status WO = Selesai, User Input = username, Waktu Selesai terisi otomatis
  -> hasil disinkronkan ke pusat
```

### 2.1 Kunci relasi

- `Kode Temuan` adalah **parent key permanen**, diwariskan dari `Inp_Temuan`, dan tidak boleh diubah.
- `Kode WO` inspeksi tidak digunakan sebagai identitas WO Har.
- `Kode WO` Har adalah **execution key baru** yang dibuat ketika Koordinator meneruskan temuan.
- Satu `Kode Temuan` dapat mempunyai beberapa `Kode WO` tindak lanjut.
- Satu `Kode WO` dapat mempunyai banyak pekerjaan.
- Satu pekerjaan dapat mempunyai banyak material.
- `Jenis WO` membedakan sumber/jenis tindak lanjut: `WO Har Jar`, `WO Har Du`, atau `WO ROW`.

```text
Inp_Temuan (Kode Temuan)
  1 -> n WO_Har_* (Kode WO baru, Kode Temuan tetap)
  1 -> n Detail Pekerjaan (Kode WO, Kode Pekerjaan)
  1 -> n Detail Material melalui Kode Pekerjaan
```

## 3. Pemetaan header WO

### 3.1 Diwariskan dari `Inp_Temuan` dan immutable

- `Kode Temuan`
- `Kode UIW`
- `Kode UP3`
- `Kode ULP`
- `ULP`
- `Hari`
- `Tanggal`
- `Penyulang`
- `Section`
- `Segmen` khusus `WO_Har_Jar`
- `Nomor Gardu` khusus `WO_Har_Du`
- `Jenis Object`
- `Tier`
- `Temuan`
- `Prioritas`
- `Koordinat`
- `Lat`
- `Long`
- `Foto Temuan`
- `Link Foto Temuan`
- `Foto Tiang Sekitar`
- `Link Foto Tiang Sekitar`
- `Folder Path`

### 3.2 Dibuat atau diisi Koordinator

- `Kode WO`: dibuat ulang sebagai identitas eksekusi.
- `Pekerjaan (Padam / Tanpa Padam)`
- `Jenis WO`: otomatis sesuai sumber sheet, bukan input petugas.
- `Tim Eksekusi`
- `Tanggal Penugasan`
- `Catatan Koordinator / TL`
- `Nama Koordinator`
- `Status WO`: nilai awal sebelum diunduh petugas.

### 3.3 Diisi otomatis atau oleh petugas eksekusi

- `Foto Sesudah`: diambil petugas.
- `Link Foto Sesudah`: diisi server setelah upload.
- `Catatan Petugas`: diisi petugas.
- `User Input`: otomatis dari `username` sesi.
- `Waktu Mulai`: otomatis saat card WO diklik pertama kali.
- `Waktu Selesai`: otomatis saat hasil lengkap disimpan.
- `Status WO`: otomatis menjadi `Progress Pekerjaan` saat card WO diklik dan `Selesai` saat disimpan.

Kolom `Durasi` tidak digunakan.

## 4. Struktur detail pekerjaan

Satu baris merepresentasikan satu pekerjaan/tindak lanjut pada satu WO. Struktur yang disepakati:

```text
No
Kode Pekerjaan
Kode WO
Kode Temuan
Kode UIW
Kode UP3
Kode ULP
ULP
Hari
Tanggal
Penyulang
Section
Segmen
Nomor Gardu
Jenis Object
Tier
Temuan
Prioritas
Jenis WO
Koordinat
Lat
Long
Uraian Pekerjaan
User Input
Waktu Input
```

Aturan:

- `Kode Pekerjaan` unik dan idempoten.
- `Kode WO` wajib menunjuk header WO Har.
- `Kode Temuan` tetap menunjuk parent pada `Inp_Temuan`.
- `Segmen` hanya berlaku untuk `WO Har Jar`.
- `Nomor Gardu` hanya berlaku untuk `WO Har Du`.
- `Jenis WO` membedakan `WO Har Jar`, `WO Har Du`, dan `WO ROW`; nilainya berasal dari sumber, bukan input manual.
- Data identitas, aset, temuan, koordinat, dan foto parent yang masuk ke detail tetap mengikuti lineage dan tidak diedit petugas.

## 5. Struktur detail material

Satu baris merepresentasikan satu material yang dipakai pada satu pekerjaan.

```text
No
Kode Penggunaan Material
Kode Pekerjaan
Kode WO
Kode Temuan
Kode UIW
Kode UP3
Kode ULP
ULP
Hari
Tanggal
Penyulang
Section
Segmen
Nomor Gardu
Jenis Object
Tier
Temuan
Prioritas
Jenis WO
Koordinat
Lat
Long
Uraian Pekerjaan
Material
Jumlah
Satuan
Kepemilikan
Catatan
User Input
Waktu Input
```

Aturan:

- `Kode Penggunaan Material` unik dan menjadi idempotency key.
- `Kode Pekerjaan` wajib menunjuk baris pada detail pekerjaan.
- `Kode WO` dan `Kode Temuan` disimpan untuk audit serta pencarian parent-child.
- `Jenis WO` cukup menjadi pembeda; tidak perlu kolom `Jenis Modul`.
- Material bersifat opsional per pekerjaan.
- Jika pekerjaan memerlukan material, minimal satu baris material wajib diisi.
- `Jumlah` harus lebih besar dari nol.
- Material dipilih dari `Master_Material`; nama dan satuan dapat disalin sebagai snapshot.

## 6. Alasan keputusan

Menyimpan banyak pekerjaan atau material di satu baris WO akan menghasilkan kolom berulang, batas jumlah yang kaku, query yang sulit, dan risiko data tidak konsisten. Model header-detail menjaga `WO_Har_Jar` dan `WO_Har_Du` tetap satu baris per WO, sementara jumlah pekerjaan dan material dapat berkembang tanpa mengubah struktur sheet.

## 7. Hal yang belum diputuskan

- Daftar master `Jenis Pekerjaan` untuk Har Jar dan Har Du.
- Apakah satu material boleh dipakai untuk beberapa pekerjaan atau wajib terkait tepat satu `Kode Pekerjaan`.
- Apakah semua pekerjaan wajib selesai sebelum WO dapat disimpan, atau sebagian boleh ditandai tidak dikerjakan beserta alasan.
- Format final `Kode Pekerjaan` dan `Kode Penggunaan Material`.
- Status awal WO sebelum `Progress Pekerjaan`.
- Mekanisme penutupan parent WO inspeksi setelah seluruh tindak lanjut selesai.
