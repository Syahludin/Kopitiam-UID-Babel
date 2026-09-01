import 'dart:io';
import 'dart:isolate';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../models/temuan_inspeksi.dart';

class PhotoWatermarkService {
  static const _panelWidth = 900;
  static const _panelHeight = 440;
  static const _margin = 44;

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
    final scale = image.width / 2048.0;
    int px(num value) => (value * scale).round();

    final panelWidth = px(
      _panelWidth,
    ).clamp(px(700), image.width - px(88)).toInt();
    final panelHeight = px(
      _panelHeight,
    ).clamp(px(380), image.height - px(88)).toInt();
    final left = px(_margin);
    final top = image.height - panelHeight - px(_margin);
    final right = left + panelWidth;
    final bottom = top + panelHeight;

    // Background panel
    img.fillRect(
      image,
      x1: left,
      y1: top,
      x2: right,
      y2: bottom,
      radius: px(14),
      color: img.ColorRgba8(8, 28, 48, 224),
    );
    // Header bar
    img.fillRect(
      image,
      x1: left,
      y1: top,
      x2: right,
      y2: top + px(82),
      radius: px(14),
      color: img.ColorRgba8(10, 54, 88, 242),
    );
    img.fillRect(
      image,
      x1: left,
      y1: top + px(74),
      x2: right,
      y2: top + px(82),
      color: img.ColorRgba8(10, 54, 88, 242),
    );
    // Logo box
    img.fillRect(
      image,
      x1: left + px(17),
      y1: top + px(14),
      x2: left + px(65),
      y2: top + px(62),
      radius: px(8),
      color: img.ColorRgba8(66, 205, 224, 255),
    );

    // Logo text "KP"
    _draw(
      image,
      'KP',
      x: left + px(23),
      y: top + px(23),
      font: img.arial24,
      color: img.ColorRgb8(7, 38, 65),
    );
    // Brand name
    _draw(
      image,
      'Kopitiam',
      x: left + px(80),
      y: top + px(12),
      font: img.arial24,
    );
    // Subtitle
    _draw(
      image,
      'Kontrol Pemeliharaan dan Inspeksi Aset Mandiri',
      x: left + px(80),
      y: top + px(46),
      font: img.arial14,
      color: img.ColorRgb8(187, 207, 220),
    );

    // Photo label badge
    final badge = photoLabel.toUpperCase();
    final isEnvironment = photoLabel.toLowerCase().contains('lingkungan');
    final badgeWidth = px(isEnvironment ? 200 : 160);
    img.fillRect(
      image,
      x1: right - badgeWidth - px(16),
      y1: top + px(20),
      x2: right - px(16),
      y2: top + px(58),
      radius: px(6),
      color: img.ColorRgba8(188, 225, 75, 255),
    );
    _draw(
      image,
      _limit(badge, 24),
      x: right - badgeWidth - px(6),
      y: top + px(30),
      font: img.arial14,
      color: img.ColorRgb8(28, 55, 25),
    );

    // Kode temuan
    _draw(
      image,
      _limit(item.kodeTemuan, 48),
      x: left + px(18),
      y: top + px(98),
      font: img.arial24,
    );
    // Temuan & object
    _draw(
      image,
      _limit('${item.temuan} | ${item.jenisObject}', 58),
      x: left + px(18),
      y: top + px(134),
      font: img.arial14,
      color: img.ColorRgb8(66, 205, 224),
    );

    // Divider
    img.fillRect(
      image,
      x1: left + px(18),
      y1: top + px(164),
      x2: right - px(18),
      y2: top + px(165),
      color: img.ColorRgba8(116, 151, 171, 110),
    );

    // Info rows
    final dateTime = item.waktuInput.isNotEmpty
        ? item.waktuInput
        : '${item.hari}, ${item.tanggal}';
    _row(image, 'WAKTU', _limit(dateTime, 58), left, top + px(182));
    _row(
      image,
      'LOKASI',
      _limit('${item.koordinat} | GPS TERKUNCI <= 5 M', 58),
      left,
      top + px(228),
      accent: true,
    );
    _row(
      image,
      'AREA',
      _limit('${item.ulp} | Penyulang ${item.penyulang}', 58),
      left,
      top + px(274),
    );
    _row(
      image,
      'SEGMEN',
      _limit('${item.section} | ${item.segmen}', 58),
      left,
      top + px(320),
    );
    _row(
      image,
      'TIER',
      _limit('${item.tier} | Prioritas ${item.prioritas}', 58),
      left,
      top + px(366),
    );

    final target = File(
      p.join(
        p.dirname(source.path),
        '${p.basenameWithoutExtension(source.path)}_wm.jpg',
      ),
    );
    target.writeAsBytesSync(img.encodeJpg(image, quality: 85), flush: true);
    if (target.lengthSync() == 0) {
      throw StateError('Watermark foto gagal disimpan.');
    }
    return target.path;
  }

  static void _row(
    img.Image image,
    String label,
    String value,
    int left,
    int y, {
    bool accent = false,
  }) {
    _draw(
      image,
      label,
      x: left + 18,
      y: y,
      font: img.arial14,
      color: img.ColorRgb8(116, 164, 190),
    );
    _draw(
      image,
      value,
      x: left + 120,
      y: y,
      font: img.arial14,
      color: accent
          ? img.ColorRgb8(188, 225, 75)
          : img.ColorRgb8(232, 240, 244),
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
      color: color ?? img.ColorRgb8(244, 248, 250),
    );
  }

  static String _limit(String value, int max) {
    final clean = value.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    return clean.length <= max ? clean : '${clean.substring(0, max - 3)}...';
  }
}
