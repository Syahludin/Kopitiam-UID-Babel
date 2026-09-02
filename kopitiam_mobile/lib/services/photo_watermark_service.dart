import 'dart:io';
import 'dart:isolate';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../models/temuan_inspeksi.dart';

class PhotoWatermarkService {
  static Future<String> render({
    required String sourcePath,
    required TemuanInspeksi item,
    required String photoLabel,
  }) {
    return Isolate.run(
      () => _renderSync(
        sourcePath: sourcePath,
        item: item,
        photoLabel: photoLabel,
      ),
    );
  }

  static String _renderSync({
    required String sourcePath,
    required TemuanInspeksi item,
    required String photoLabel,
  }) {
    final source = File(sourcePath);
    final decoded = img.decodeImage(source.readAsBytesSync());
    if (decoded == null) {
      throw StateError('Foto tidak dapat dibaca untuk proses watermark.');
    }

    final image = img.bakeOrientation(decoded);
    final imgW = image.width;
    final imgH = image.height;

    // 1. Dimensi & Posisi Panel Utama (Kiri Bawah): 40% Lebar & 30% Tinggi Foto
    final panelWidth = (imgW * 0.40).round();
    final panelHeight = (imgH * 0.30).round();
    final marginX = (imgW * 0.025).round();
    final marginY = (imgH * 0.025).round();

    final left = marginX;
    final top = imgH - panelHeight - marginY;
    final right = left + panelWidth;
    final bottom = top + panelHeight;
    final radius = (panelWidth * 0.035).round().clamp(8, 24);

    // Warna Palette
    final darkBg = img.ColorRgba8(15, 22, 32, 224); // rgba(15, 22, 32, 0.88)
    final limeAccent = img.ColorRgba8(57, 255, 20, 255); // Hijau Neon
    final whiteText = img.ColorRgba8(255, 255, 255, 255);
    final subText = img.ColorRgba8(203, 213, 225, 255);

    // Background Dark Panel Utama
    img.fillRect(
      image,
      x1: left,
      y1: top,
      x2: right,
      y2: bottom,
      radius: radius,
      color: darkBg,
    );

    // Padding internal panel
    final padX = (panelWidth * 0.045).round();
    final padY = (panelHeight * 0.045).round();
    final contentLeft = left + padX;
    final contentRight = right - padX;

    // ==========================================
    // BARIS 1: Header Kiri Atas (Logo PLN + Kode Pekerjaan + Unit/ULP)
    // ==========================================
    final logoSize = (panelHeight * 0.18).round().clamp(24, 64);
    final logoX = contentLeft;
    final logoY = top + padY;

    // Badge Logo PLN Kuning/Biru/Merah
    img.fillRect(
      image,
      x1: logoX,
      y1: logoY,
      x2: logoX + logoSize,
      y2: logoY + logoSize,
      radius: (logoSize * 0.2).round(),
      color: img.ColorRgba8(250, 204, 21, 255), // Kuning PLN
    );
    _draw(
      image,
      'PLN',
      x: logoX + (logoSize * 0.12).round(),
      y: logoY + (logoSize * 0.2).round(),
      font: logoSize > 36 ? img.arial24 : img.arial14,
      color: img.ColorRgba8(14, 116, 144, 255), // Cyan/Blue PLN
    );

    // Kode Temuan (Kode Pekerjaan Utama) & Unit/ULP
    final headerTextX = logoX + logoSize + (panelWidth * 0.03).round();
    final kodePekerjaan = item.kodeTemuan.isNotEmpty ? item.kodeTemuan : item.kodeWo;
    _draw(
      image,
      _limit(kodePekerjaan, 28),
      x: headerTextX,
      y: logoY,
      font: img.arial24,
      color: whiteText,
    );

    final ulpText = item.ulp.isNotEmpty ? item.ulp : 'ULP Toboali';
    final timText = item.jenisObject.isNotEmpty ? 'Inspeksi ${item.jenisObject}' : 'Inspeksi Jaringan';
    _draw(
      image,
      _limit('$ulpText · $timText', 36),
      x: headerTextX,
      y: logoY + (logoSize * 0.55).round(),
      font: img.arial14,
      color: subText,
    );

    // ==========================================
    // BARIS 2: Pemisah 2 Garis Horizontal Hijau Neon
    // ==========================================
    final lineY1 = logoY + logoSize + (panelHeight * 0.035).round();
    final lineY2 = lineY1 + (panelHeight * 0.02).round();
    img.drawLine(
      image,
      x1: contentLeft,
      y1: lineY1,
      x2: contentRight,
      y2: lineY1,
      color: limeAccent,
      thickness: 1.5,
    );
    img.drawLine(
      image,
      x1: contentLeft,
      y1: lineY2,
      x2: contentRight,
      y2: lineY2,
      color: limeAccent,
      thickness: 1.5,
    );

    // ==========================================
    // BARIS 3: Waktu & Tanggal (Jam Digital Besar + Hari/Tanggal)
    // ==========================================
    final timeY = lineY2 + (panelHeight * 0.035).round();
    final timeStr = _extractTime(item.waktuInput);
    final dayStr = item.hari.isNotEmpty ? item.hari : _extractDay(item.waktuInput);
    final dateStr = item.tanggal.isNotEmpty ? item.tanggal : _extractDate(item.waktuInput);

    // Jam Digital Besar
    _draw(
      image,
      timeStr,
      x: contentLeft,
      y: timeY,
      font: img.arial48,
      color: whiteText,
    );

    // Di samping kanan jam: Hari & Tanggal
    final dateLeft = contentLeft + (panelWidth * 0.32).round();
    _draw(
      image,
      dayStr,
      x: dateLeft,
      y: timeY + (panelHeight * 0.01).round(),
      font: img.arial24,
      color: limeAccent,
    );
    _draw(
      image,
      dateStr,
      x: dateLeft,
      y: timeY + (panelHeight * 0.07).round(),
      font: img.arial14,
      color: subText,
    );

    // ==========================================
    // BARIS 4, 5, 6: Bullet Hijau Neon + Informasi Lapangan
    // ==========================================
    final rowStartY = timeY + (panelHeight * 0.15).round();
    final rowSpacing = (panelHeight * 0.075).round();
    final bulletRadius = (panelHeight * 0.012).round().clamp(2, 6);

    // Baris 4: Penyulang
    _drawBulletRow(
      image,
      x: contentLeft,
      y: rowStartY,
      bulletRadius: bulletRadius,
      bulletColor: limeAccent,
      label: 'Penyulang : ',
      value: _limit(item.penyulang.isNotEmpty ? item.penyulang : '-', 32),
      font: img.arial14,
    );

    // Baris 5: Detail Spesifik Tim (Temuan : <No Gardu/Tiang / Segmen> (<Tier/Kategori>))
    final lokasiTemuan = item.segmen.isNotEmpty
        ? item.segmen
        : (item.section.isNotEmpty ? item.section : item.temuan);
    final tierInfo = item.tier.isNotEmpty ? item.tier : item.prioritas;
    final findingDetail = tierInfo.isNotEmpty ? '$lokasiTemuan ($tierInfo)' : lokasiTemuan;

    _drawBulletRow(
      image,
      x: contentLeft,
      y: rowStartY + rowSpacing,
      bulletRadius: bulletRadius,
      bulletColor: limeAccent,
      label: 'Temuan    : ',
      value: _limit(findingDetail, 32),
      font: img.arial14,
    );

    // Baris 6: Koordinat
    final coordText = item.koordinat.isNotEmpty ? item.koordinat : '${item.lat}, ${item.long}';
    _drawBulletRow(
      image,
      x: contentLeft,
      y: rowStartY + (rowSpacing * 2),
      bulletRadius: bulletRadius,
      bulletColor: limeAccent,
      label: 'Koordinat : ',
      value: _limit(coordText, 34),
      font: img.arial14,
    );

    // ==========================================
    // IDENTITAS SUDUT KANAN BAWAH (Badge Logo Kopitiam Bersih Rounded)
    // ==========================================
    final badgeW = (imgW * 0.14).round().clamp(130, 240);
    final badgeH = (imgH * 0.065).round().clamp(44, 90);
    final badgeRight = imgW - marginX;
    final badgeBottom = imgH - marginY;
    final badgeLeft = badgeRight - badgeW;
    final badgeTop = badgeBottom - badgeH;
    final badgeRadius = (badgeH * 0.28).round();

    // Background Putih Rounded
    img.fillRect(
      image,
      x1: badgeLeft,
      y1: badgeTop,
      x2: badgeRight,
      y2: badgeBottom,
      radius: badgeRadius,
      color: img.ColorRgba8(255, 255, 255, 245),
    );

    // Ikon / Badge KP
    final kpBoxSize = (badgeH * 0.65).round();
    final kpBoxX = badgeLeft + (badgeW * 0.08).round();
    final kpBoxY = badgeTop + ((badgeH - kpBoxSize) / 2).round();

    img.fillRect(
      image,
      x1: kpBoxX,
      y1: kpBoxY,
      x2: kpBoxX + kpBoxSize,
      y2: kpBoxY + kpBoxSize,
      radius: (kpBoxSize * 0.25).round(),
      color: img.ColorRgba8(10, 62, 116, 255), // Primary Blue Kopitiam
    );
    _draw(
      image,
      'KP',
      x: kpBoxX + (kpBoxSize * 0.15).round(),
      y: kpBoxY + (kpBoxSize * 0.15).round(),
      font: img.arial14,
      color: img.ColorRgba8(255, 255, 255, 255),
    );

    // Text Kopitiam & Subtitle
    final textKpX = kpBoxX + kpBoxSize + (badgeW * 0.06).round();
    _draw(
      image,
      'Kopitiam',
      x: textKpX,
      y: badgeTop + (badgeH * 0.18).round(),
      font: img.arial24,
      color: img.ColorRgba8(7, 27, 48, 255), // Dark Navy
    );
    _draw(
      image,
      'UID Babel',
      x: textKpX,
      y: badgeTop + (badgeH * 0.56).round(),
      font: img.arial14,
      color: img.ColorRgba8(100, 116, 139, 255),
    );

    final target = File(
      p.join(
        p.dirname(source.path),
        '${p.basenameWithoutExtension(source.path)}_wm.jpg',
      ),
    );
    target.writeAsBytesSync(img.encodeJpg(image, quality: 88), flush: true);
    if (target.lengthSync() == 0) {
      throw StateError('Watermark foto gagal disimpan.');
    }
    return target.path;
  }

  static void _drawBulletRow(
    img.Image image, {
    required int x,
    required int y,
    required int bulletRadius,
    required img.Color bulletColor,
    required String label,
    required String value,
    required img.BitmapFont font,
  }) {
    // Bullet neon
    img.fillCircle(
      image,
      x: x + bulletRadius,
      y: y + 8,
      radius: bulletRadius,
      color: bulletColor,
    );

    // Label
    final textX = x + (bulletRadius * 2) + 8;
    _draw(
      image,
      label,
      x: textX,
      y: y,
      font: font,
      color: img.ColorRgba8(57, 255, 20, 255), // Lime/Green
    );

    // Value
    final labelWidth = label.length * 9;
    _draw(
      image,
      value,
      x: textX + labelWidth,
      y: y,
      font: font,
      color: img.ColorRgba8(241, 245, 249, 255), // Light Slate / White
    );
  }

  static void _draw(
    img.Image image,
    String text, {
    required int x,
    required int y,
    required img.BitmapFont font,
    img.Color? color,
  }) {
    img.drawString(
      image,
      text,
      font: font,
      x: x,
      y: y,
      color: color ?? img.ColorRgba8(244, 248, 250, 255),
    );
  }

  static String _extractTime(String stamp) {
    final match = RegExp(r'(\d{2}:\d{2})').firstMatch(stamp);
    if (match != null) return match.group(1)!;
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  static String _extractDay(String stamp) {
    final days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    return days[DateTime.now().weekday % 7];
  }

  static String _extractDate(String stamp) {
    if (stamp.contains(',')) {
      final parts = stamp.split(',');
      if (parts.isNotEmpty) return parts.first.trim();
    }
    final now = DateTime.now();
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }

  static String _limit(String value, int max) {
    final clean = value.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    return clean.length <= max ? clean : '${clean.substring(0, max - 3)}...';
  }
}
