# Ikon KOPITIAM

## Menu utama

| Berkas | Fungsi |
| --- | --- |
| `work_order.svg` | Clipboard teknis dengan penanda validasi pekerjaan. |
| `beranda.svg` | Rumah operasional dengan garis horizon internal. |
| `pengaturan.svg` | Dial kontrol ringan, menggantikan gear generik lama. |

## Aturan visual

- Grid: 32 × 32.
- Area gambar utama: sekitar 24 × 24, dengan safe area 4 unit.
- Stroke: 2.2, `linecap` dan `linejoin` membulat.
- Warna: memakai `currentColor`, bukan warna tertanam, agar Flutter dapat mengatur state.
- State pasif: biru KOPITIAM `#004D8C`.
- State aktif: emas `#FDC730` pada bubble navy `#072D43`.
- Ukuran navigasi: 23 px pasif, 32 sampai 34 px aktif.

Desain disetujui pada katalog interaktif `kopitiam-design-menu.html`.
