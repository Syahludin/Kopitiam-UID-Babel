# PRD Har - WO Har Jar dan WO Har Du

> Dokumen ini diperbarui bertahap. Bagian yang sudah disepakati dikunci sebagai keputusan; bagian berikutnya ditambahkan setelah review.

## 1. Keputusan model data

Satu baris pada `WO_Har_Jar` atau `WO_Har_Du` merepresentasikan **satu Work Order eksekusi**, bukan satu kegiatan dan bukan satu penggunaan material. Karena satu WO dapat memiliki banyak kegiatan dan setiap kegiatan dapat memakai banyak material, kegiatan serta material tidak boleh dipaksakan menjadi kolom berulang pada baris WO.

Model yang dipakai:

- **Header WO (1 baris):** `WO_Har_Jar` atau `WO_Har_Du`.
- **Detail kegiatan (0..n baris):** sheet anak `WO_Har_Kegiatan`.
- **Detail material (0..n baris):** sheet anak `WO_Har_Material`.
- Relasi header ke detail menggunakan `Kode WO`.
- Relasi seluruh WO tindak lanjut ke temuan asal menggunakan `Kode Temuan`.

Dengan model ini, satu WO tetap satu baris, tetapi petugas dapat mencatat banyak kegiatan dan banyak material tanpa menambah kolom dinamis seperti `Kegiatan 1`, `Kegiatan 2`, atau `Material 1`.

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
  -> petugas mengisi satu atau lebih kegiatan dan material yang digunakan
  -> petugas mengambil Foto Sesudah dan menyimpan
  -> Status WO = Selesai, User Input = username, Waktu Selesai terisi otomatis
  -> hasil disinkronkan ke pusat
```

### 2.1 Kunci relasi

- `Kode Temuan` adalah **parent key permanen**, diwariskan dari `Inp_Temuan`, dan tidak boleh diubah.
- `Kode WO` inspeksi tidak digunakan sebagai identitas WO Har.
- `Kode WO` Har adalah **execution key baru** yang dibuat ketika Koordinator meneruskan temuan.
- Satu `Kode Temuan` dapat mempunyai beberapa `Kode WO` tindak lanjut.
- Satu `Kode WO` dapat mempunyai banyak kegiatan.
- Satu kegiatan dapat mempunyai banyak material.

```text
Inp_Temuan (Kode Temuan)
  1 -> n WO_Har_* (Kode WO baru, Kode Temuan tetap)
  1 -> n WO_Har_Kegiatan
  1 -> n WO_Har_Material melalui Kode Kegiatan
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
- `Jenis WO`
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
- `Status WO`: otomatis menjadi `Progress Pekerjaan` saat card diklik dan `Selesai` saat disimpan.

Kolom `Durasi` tidak digunakan.

## 4. Rancangan sheet detail

### 4.1 `WO_Har_Kegiatan`

Satu baris merepresentasikan satu kegiatan dalam satu WO.

```text
No
Kode Kegiatan
Kode WO
Kode Temuan
Urutan
Jenis Kegiatan
Uraian Kegiatan
Volume
Satuan
Status Kegiatan
Catatan
User Input
Waktu Input
Waktu Selesai
```

Aturan:

- `Kode Kegiatan` unik dan idempoten.
- `Kode WO` wajib menunjuk header WO Har.
- `Kode Temuan` disalin untuk audit dan pencarian parent-child.
- WO hanya boleh disimpan sebagai `Selesai` jika seluruh kegiatan wajib sudah lengkap.
- Daftar `Jenis Kegiatan` idealnya berasal dari master, bukan teks bebas, tetapi `Uraian Kegiatan` boleh manual.

### 4.2 `WO_Har_Material`

Satu baris merepresentasikan satu material yang dipakai pada satu kegiatan.

```text
No
Kode Penggunaan Material
Kode WO
Kode Kegiatan
Kode Material
Material
Jumlah
Satuan
Kepemilikan
Keterangan
User Input
Waktu Input
```

Aturan:

- Material bersifat opsional per kegiatan.
- Jika kegiatan memerlukan material, minimal satu baris material wajib diisi.
- `Jumlah` harus lebih besar dari nol.
- `Kode Penggunaan Material` menjadi idempotency key agar retry tidak menggandakan material.
- Material dipilih dari `Master_Material`; nama dan satuan dapat disalin sebagai snapshot.

## 5. Alasan keputusan

Menyimpan banyak kegiatan atau material di satu baris WO akan menghasilkan kolom berulang, batas jumlah yang kaku, query yang sulit, dan risiko data tidak konsisten. Model header-detail menjaga `WO_Har_Jar` dan `WO_Har_Du` tetap satu baris per WO, sementara jumlah kegiatan dan material dapat berkembang tanpa mengubah struktur sheet.

## 6. Hal yang belum diputuskan

- Daftar master `Jenis Kegiatan` untuk Har Jar dan Har Du.
- Apakah satu material boleh dipakai untuk beberapa kegiatan atau wajib terkait tepat satu kegiatan.
- Apakah semua kegiatan wajib selesai sebelum WO dapat disimpan, atau sebagian kegiatan boleh ditandai tidak dikerjakan beserta alasan.
- Format final `Kode Kegiatan` dan `Kode Penggunaan Material`.
- Status awal WO sebelum `Progress Pekerjaan`.
- Mekanisme penutupan parent WO inspeksi setelah seluruh tindak lanjut selesai.
