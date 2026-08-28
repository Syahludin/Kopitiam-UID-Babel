# Branding KOPITIAM

Satu sumber aset untuk semua ikon aplikasi.

## Isi

| Berkas | Fungsi |
| --- | --- |
| `kopitiam_logo.svg` | Emblem KOPITIAM lengkap (cincin emas, teks melingkar, perisai, petir sirkuit, roda gigi, cangkir kopi). Sumber vektor yang selalu ada di repo. |
| `kopitiam_logo_master.png` | Opsional. Artwork raster resmi (persegi, 1024 px, latar transparan). Jika berkas ini ada, generator memakainya dan mengabaikan SVG. |

## Cara memakai artwork raster resmi

1. Simpan artwork sebagai `branding/kopitiam_logo_master.png` (persegi, minimal 1024 x 1024, latar transparan, cincin emas utuh tanpa terpotong).
2. Commit dan push. Workflow `App Icons` akan otomatis regenerasi semua ikon launcher.

## Regenerasi manual

```bash
pip install pillow cairosvg
python3 ci/generate_app_icons.py
```

## Yang dihasilkan generator

- Android: `mipmap-*/launcher_icon.png`, `ic_launcher.png`, `launcher_icon_foreground.png`, adaptive icon `mipmap-anydpi-v26/launcher_icon.xml`, dan warna latar `values/ic_launcher_background.xml`.
- iOS: seluruh berkas di `Runner/Assets.xcassets/AppIcon.appiconset` beserta `Contents.json` (tanpa alpha, sesuai syarat App Store).
- Web dan PWA: `web/icons/Icon-192.png`, `Icon-512.png`, versi maskable, dan `web/favicon.png`.

Warna latar ikon: `#072D43`.
