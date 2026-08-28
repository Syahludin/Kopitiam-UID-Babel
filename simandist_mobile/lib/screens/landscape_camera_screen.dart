import 'dart:io';

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

  @override
  State<LandscapeCameraScreen> createState() =>
      _LandscapeCameraScreenState();
}

class _LandscapeCameraScreenState extends State<LandscapeCameraScreen> {
  static const outputWidth = 2048;
  CameraController? _controller;
  String? _error;
  bool _capturing = false;

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
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<String> _normalizeLandscape(String sourcePath) async {
    final source = File(sourcePath);
    final decoded = img.decodeImage(await source.readAsBytes());
    if (decoded == null) {
      throw StateError('Format foto kamera tidak dapat dibaca.');
    }
    var normalized = img.bakeOrientation(decoded);
    if (normalized.height > normalized.width) {
      normalized = img.copyRotate(normalized, angle: 90);
    }
    final resized = img.copyResize(
      normalized,
      width: outputWidth,
      interpolation: img.Interpolation.cubic,
    );
    final target = File(
      p.join(
        p.dirname(sourcePath),
        '${p.basenameWithoutExtension(sourcePath)}_2048.jpg',
      ),
    );
    await target.writeAsBytes(img.encodeJpg(resized, quality: 80), flush: true);
    if (await target.length() == 0) {
      throw StateError('Foto landscape gagal diproses.');
    }
    return target.path;
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
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: const Color(0xFF071B30),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: controller == null || !controller.value.isInitialized
                  ? Center(
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
                  : Center(
                      child: AspectRatio(
                        aspectRatio: controller.value.aspectRatio,
                        child: CameraPreview(controller),
                      ),
                    ),
            ),
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
                ),
              ),
            ),
            const Positioned(
              left: 18,
              bottom: 20,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xCC071B30),
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    'Landscape wajib • Output 2048 px',
                    style: TextStyle(
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
    );
  }
}
