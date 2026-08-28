import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../models/temuan_inspeksi.dart';

class PhotoWatermarkService {
  static const _panelWidth = 700;
  static const _panelHeight = 350;
  static const _margin = 44;

  static Future<String> render({
    required String sourcePath,
    required TemuanInspeksi item,
    required String photoLabel,
  }) async {
    final source = File(sourcePath);
    final decoded = img.decodeImage(await source.readAsBytes());
    if (decoded == null) {
      throw StateError('Foto tidak dapat dibaca untuk proses watermark.');
    }

    final image = img.bakeOrientation(decoded);
    final scale = image.width / 2048.0;
    int px(num value) => (value * scale).round();

    final panelWidth = px(
      _panelWidth,
    ).clamp(px(560), image.width - px(88)).toInt();
    final panelHeight = px(
      _panelHeight,
    ).clamp(px(300), image.height - px(88)).toInt();
    final left = px(_margin);
    final top = image.height - panelHeight - px(_margin);
    final right = left + panelWidth;
    final bottom = top + panelHeight;

    img.fillRect(
      image,
      x1: left,
      y1: top,
      x2: right,
      y2: bottom,
      radius: px(14),
      color: img.ColorRgba8(8, 28, 48, 224),
    );
    img.fillRect(
      image,
      x1: left,
      y1: top,
      x2: right,
      y2: top + px(72),
      radius: px(14),
      color: img.ColorRgba8(10, 54, 88, 242),
    );
    img.fillRect(
      image,
      x1: left,
      y1: top + px(64),
      x2: right,
      y2: top + px(72),
      color: img.ColorRgba8(10, 54, 88, 242),
    );
    img.fillRect(
      image,
      x1: left + px(17),
      y1: top + px(16),
      x2: left + px(61),
      y2: top + px(58),
      radius: px(8),
      color: img.ColorRgba8(66, 205, 224, 255),
    );

    _draw(
      image,
      'SM',
      x: left + px(23),
      y: top + px(25),
      font: img.arial24,
      color: img.ColorRgb8(7, 38, 65),
    );
    _draw(
      image,
      'SiManDist',
      x: left + px(78),
      y: top + px(14),
      font: img.arial24,
    );
    _draw(
      image,
      'Sistem Manajemen Distribusi',
      x: left + px(78),
      y: top + px(43),
      font: img.arial14,
      color: img.ColorRgb8(187, 207, 220),
    );

    final badge = photoLabel.toUpperCase();
    final isEnvironment = photoLabel.toLowerCase().contains('lingkungan');
    final badgeWidth = px(isEnvironment ? 180 : 144);
    img.fillRect(
      image,
      x1: right - badgeWidth - px(16),
      y1: top + px(20),
      x2: right - px(16),
      y2: top + px(53),
      radius: px(6),
      color: img.ColorRgba8(188, 225, 75, 255),
    );
    _draw(
      image,
      _limit(badge, 22),
      x: right - badgeWidth - px(8),
      y: top + px(29),
      font: img.arial14,
      color: img.ColorRgb8(28, 55, 25),
    );

    _draw(
      image,
      _limit(item.kodeTemuan, 43),
      x: left + px(18),
      y: top + px(88),
      font: img.arial24,
    );
    _draw(
      image,
      _limit('${item.temuan} | ${item.jenisObject}', 52),
      x: left + px(18),
      y: top + px(120),
      font: img.arial14,
      color: img.ColorRgb8(66, 205, 224),
    );

    img.fillRect(
      image,
      x1: left + px(18),
      y1: top + px(148),
      x2: right - px(18),
      y2: top + px(149),
      color: img.ColorRgba8(116, 151, 171, 110),
    );

    final dateTime = item.waktuInput.isNotEmpty
        ? item.waktuInput
        : '${item.hari}, ${item.tanggal}';
    _row(image, 'WAKTU', _limit(dateTime, 54), left, top + px(166));
    _row(
      image,
      'LOKASI',
      _limit('${item.koordinat} | GPS TERKUNCI <= 5 M', 54),
      left,
      top + px(207),
      accent: true,
    );
    _row(
      image,
      'AREA',
      _limit('${item.ulp} | Penyulang ${item.penyulang}', 54),
      left,
      top + px(248),
    );
    _row(
      image,
      'SEGMEN',
      _limit('${item.section} | ${item.segmen}', 54),
      left,
      top + px(289),
    );

    final target = File(
      p.join(
        p.dirname(source.path),
        '${p.basenameWithoutExtension(source.path)}_wm.jpg',
      ),
    );
    await target.writeAsBytes(img.encodeJpg(image, quality: 82), flush: true);
    if (await target.length() == 0) {
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
      x: left + 112,
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
