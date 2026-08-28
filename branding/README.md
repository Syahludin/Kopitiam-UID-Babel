# Branding KOPITIAM

Satu sumber gambar untuk semua aset branding aplikasi.

## Sumber logo

Generator memeriksa berkas berikut secara berurutan dan memakai yang pertama ditemukan:

1. `kopitiam_mobile/assets/branding/kopitiam-logo-master-2048.png` — artwork resmi yang dipakai sekarang.
2. `branding/kopitiam_logo_master.png` — lokasi alternatif bila ingin menaruh master di root.
3. `branding/kopitiam_logo.svg` — cadangan vektor bila kedua berkas raster tidak ada.

Syarat berkas master: persegi, minimal 1024 px (2048 px lebih baik), latar transparan, cincin emas utuh tanpa terpotong.

## Regenerasi

Otomatis lewat workflow `App Icons` setiap kali sumber branding atau generator berubah. Manual:

```bash
pip install pillow cairosvg
python3 ci/generate_app_icons.py
```

## Hasil generator

| Target | Berkas |
| --- | --- |
| Android | `mipmap-*/launcher_icon.png`, `ic_launcher.png`, `launcher_icon_foreground.png`, `mipmap-anydpi-v26/launcher_icon.xml`, `values/ic_launcher_background.xml` |
| iOS | seluruh ukuran `AppIcon.appiconset` beserta `Contents.json`, tanpa alpha sesuai syarat App Store |
| Web dan PWA | `web/icons/Icon-192.png`, `Icon-512.png`, versi maskable, `web/favicon.png` |
| Dalam aplikasi | `assets/icons/logo_app.png` (512 px, transparan) yang dipakai layar login |

Warna latar ikon: `#072D43`.
