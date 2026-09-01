import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kopitiam_mobile/screens/landscape_camera_screen.dart';

/// Verifikasi perbaikan rasio foto landscape: hasil pemotongan selalu
/// berukuran standar 4:3 (ukuran foto konvensional) dan tidak merusak konten
/// tengah. Berguna untuk memastikan foto tidak tampak "aneh/terpotong".
void main() {
  group('cropToStandardAspect (rasio foto landscape)', () {
    test('citra 4:3 tidak diubah (no-op)', () {
      final source = img.Image(width: 4032, height: 3024);
      final out = LandscapeCameraScreen.cropToStandardAspect(source);
      expect(out.width, 4032);
      expect(out.height, 3024);
      expect((out.width / out.height - 4 / 3).abs(), lessThan(0.001));
    });

    test('citra portrait diubah menjadi 4:3 landscape', () {
      final source = img.Image(width: 4032, height: 4032);
      final out = LandscapeCameraScreen.cropToStandardAspect(source);
      expect((out.width / out.height - 4 / 3).abs(), lessThan(0.001));
    });

    test('citra 16:9 dipotong simetris menjadi 4:3 tanpa kehilangan tinggi',
        () {
      final source = img.Image(width: 3840, height: 2160);
      final out = LandscapeCameraScreen.cropToStandardAspect(source);
      expect((out.width / out.height - 4 / 3).abs(), lessThan(0.001));
      // Tinggi dipertahankan penuh; bagian yang dipotong di kiri-kanan tengah.
      expect(out.height, 2160);
      expect(out.width, lessThan(3840));
    });

    test('semua input umum menghasilkan rasio 4:3 (2048 lebar setelah resize)',
        () {
      const dims = [
        (3024, 4032),
        (4032, 3024),
        (2448, 3264),
        (3840, 2160),
        (4000, 4000),
      ];
      for (final (w, h) in dims) {
        final cropped = LandscapeCameraScreen.cropToStandardAspect(
          img.Image(width: w, height: h),
        );
        expect(
          (cropped.width / cropped.height - 4 / 3).abs(),
          lessThan(0.001),
          reason: 'dimensi $w x $h harus menjadi 4:3',
        );
        final resized = img.copyResize(
          cropped,
          width: 2048,
          interpolation: img.Interpolation.linear,
        );
        expect(resized.width, 2048);
        expect(resized.height, 1536);
      }
    });
  });
}