import 'dart:io';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

class LandscapeCameraScreen extends StatefulWidget {
  final String title;

  const LandscapeCameraScreen({super.key, required this.title});

  static Future<String?> capture(
    BuildContext context, {
    required String title,
  }) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => LandscapeCameraScreen(title: title),
      ),
    );
  }
/// Menyusun [image] menjadi rasio standar 4:3 (4/3) dengan memotong bagian
  /// tengah secara simetris bila diperlukan. Mengembalikan citra 4:3 sehingga
  /// foto landscape selalu memiliki dimensi "seperti foto pada umumnya".
  static img.Image cropToStandardAspect(img.Image image) {
    const target = 4.0 / 3.0;
    final aspect = image.width / image.height;
    if ((aspect - target).abs() <= 0.001) {
      return image;
    }
    if (aspect > target) {
      // Terlalu lebar (mis. 16:9): potong tepi kiri-kanan di tengah.
      final newWidth = (image.height * target).round();
      final left = ((image.width - newWidth) / 2).round();
      return img.copyCrop(
        image,
        x: left,
        y: 0,
        width: newWidth,
        height: image.height,
      );
    }
    // Terlalu tinggi: potong tepi atas-bawah di tengah.
    final newHeight = (image.width / target).round();
    final top = ((image.height - newHeight) / 2).round();
    return img.copyCrop(
      image,
      x: 0,
      y: top,
      width: image.width,
      height: newHeight,
    );
  }

  @override
  State<LandscapeCameraScreen> createState() =>
      _LandscapeCameraScreenState();
}

class _LandscapeCameraScreenState extends State<LandscapeCameraScreen> {
  static const outputWidth = 2048;
  CameraController? _controller;
  String? _error;
  bool _capturing = false;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentZoom = 1.0;
  double _baseZoom = 1.0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('Kamera perangkat tidak tersedia.');
      }
      final back = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.landscapeLeft);
      final minZ = await controller.getMinZoomLevel();
      final maxZ = await controller.getMaxZoomLevel();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _minZoom = minZ;
        _maxZoom = maxZ;
        _currentZoom = minZ;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    _baseZoom = _currentZoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final controller = _controller;
    if (controller == null) return;
    final newZoom = (_baseZoom * details.scale).clamp(_minZoom, _maxZoom);
    controller.setZoomLevel(newZoom);
    setState(() => _currentZoom = newZoom);
  }

  Future<String> _normalizeLandscape(String sourcePath) {
    return Isolate.run(() {
      final source = File(sourcePath);
      final decoded = img.decodeImage(source.readAsBytesSync());
      if (decoded == null) {
        throw StateError('Format foto kamera tidak dapat dibaca.');
      }
      var normalized = img.bakeOrientation(decoded);
      if (normalized.height > normalized.width) {
        normalized = img.copyRotate(normalized, angle: 90);
      }
      // Buat rasio foto selalu standar 4:3 (ukuran foto konvensional) agar hasil
      // tidak tampak "aneh/terpotong". Pada sensor 4:3 normal ini adalah no-op
      // (tidak ada konten yang hilang); pada sensor non-4:3 (mis. 16:9) hanya
      // memotong bagian tepi secara simetris dari tengah.
      normalized = LandscapeCameraScreen.cropToStandardAspect(normalized);
      final resized = img.copyResize(
        normalized,
        width: outputWidth,
        interpolation: img.Interpolation.linear,
      );
      final target = File(
        p.join(
          p.dirname(sourcePath),
          '${p.basenameWithoutExtension(sourcePath)}_2048.jpg',
        ),
      );
      target.writeAsBytesSync(img.encodeJpg(resized, quality: 85), flush: true);
      if (target.lengthSync() == 0) {
        throw StateError('Foto landscape gagal diproses.');
      }
      return target.path;
    });
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) {
      return;
    }
    setState(() => _capturing = true);
    try {
      final image = await controller.takePicture();
      final file = File(image.path);
      if (!await file.exists() || await file.length() == 0) {
        throw StateError('Foto tidak tersimpan. Silakan ambil ulang.');
      }
      final landscapePath = await _normalizeLandscape(image.path);
      if (mounted) Navigator.of(context).pop(landscapePath);
    } catch (error) {
      if (mounted) {
        setState(() {
          _capturing = false;
          _error = '$error';
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  Size _previewBox(CameraController controller) {
    final preview = controller.value.previewSize ?? const Size(1280, 720);
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    return landscape
        ? Size(preview.height, preview.width)
        : Size(preview.width, preview.height);
  }

  String get _zoomLabel => '${_currentZoom.toStringAsFixed(1)}x';

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: const Color(0xFF071B30),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (controller == null || !controller.value.isInitialized)
            Center(
              child: _error == null
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
            )
          else
            GestureDetector(
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              child: ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox.fromSize(
                    size: _previewBox(controller),
                    child: CameraPreview(controller),
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  left: 18,
                  top: 14,
                  child: IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
                Positioned(
                  left: 76,
                  top: 19,
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      shadows: [
                        Shadow(color: Color(0xCC000000), blurRadius: 6),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  bottom: 20,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Color(0xCC071B30),
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        'Landscape \u2022 $_zoomLabel \u2022 Pinch to zoom',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 28,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Semantics(
                      button: true,
                      label: 'Ambil foto landscape',
                      child: InkWell(
                        onTap: _capturing ? null : _capture,
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                              color: const Color(0xFFFFB800),
                              width: 5,
                            ),
                          ),
                          child: _capturing
                              ? const Padding(
                                  padding: EdgeInsets.all(22),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: Color(0xFF004D8C),
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 32,
                                  color: Color(0xFF004D8C),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
