import 'dart:io';

import 'package:flutter/material.dart';

import '../models/wo_har_du.dart';
import '../services/high_accuracy_location_service.dart';
import '../services/wo_har_du_repository.dart';
import 'landscape_camera_screen.dart';

class FormTindakLanjutHarDuScreen extends StatefulWidget {
  final WoHarDu existing;
  final Map<String, dynamic> sesi;

  const FormTindakLanjutHarDuScreen({
    super.key,
    required this.existing,
    required this.sesi,
  });

  @override
  State<FormTindakLanjutHarDuScreen> createState() =>
      _FormTindakLanjutHarDuScreenState();
}

class _FormTindakLanjutHarDuScreenState
    extends State<FormTindakLanjutHarDuScreen> {
  final _repository = WoHarDuRepository();
  final _notes = TextEditingController();
  String _photo = '';
  String _coordinate = '';
  double? _lat;
  double? _long;
  String? _accuracy;
  bool _locating = false;
  bool _saving = false;
  bool _camera = false;

  bool get _readOnly =>
      WoHarDu.normalisasiStatus(widget.existing.statusWo) == WoHarDu.statusSelesai;

  @override
  void initState() {
    super.initState();
    _notes.text = widget.existing.catatanPetugas;
    _photo = widget.existing.fotoSesudah;
    _coordinate = widget.existing.koordinat;
    _lat = widget.existing.lat;
    _long = widget.existing.long;
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    if (_readOnly || _camera) return;
    setState(() => _camera = true);
    try {
      final result = await LandscapeCameraScreen.capture(
        context,
        title: 'Foto Sesudah Har Du',
      );
      if (result != null && mounted) setState(() => _photo = result);
    } finally {
      if (mounted) setState(() => _camera = false);
    }
  }

  Future<void> _locate() async {
    if (_readOnly || _locating) return;
    setState(() => _locating = true);
    try {
      final fix = await HighAccuracyLocationService.acquire(
        onSample: (_, accuracy) {
          if (mounted) setState(() => _accuracy = '${accuracy.toStringAsFixed(1)} m');
        },
      );
      if (mounted) {
        setState(() {
          _coordinate = fix.coordinate;
          _lat = fix.latitude;
          _long = fix.longitude;
          _accuracy = fix.accuracyLabel;
        });
      }
    } catch (error) {
      _message('$error');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _finish() async {
    if (_saving || _readOnly) return;
    if (_photo.isEmpty || _lat == null || _long == null || _coordinate.isEmpty) {
      _message('Foto Sesudah dan koordinat GPS wajib dilengkapi.');
      return;
    }
    setState(() => _saving = true);
    try {
      await _repository.simpanSelesai(
        widget.existing,
        fotoSesudah: _photo,
        koordinat: _coordinate,
        latitude: _lat!,
        longitude: _long!,
        catatan: _notes.text.trim(),
        username: '${widget.sesi['username'] ?? ''}',
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      _message(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Tindak Lanjut Har Du')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _card('Detail WO', [
              _value('Kode WO', widget.existing.kodeWo),
              _value('Nomor Gardu', widget.existing.nomorGardu),
              _value('Penyulang / Section',
                  '${widget.existing.penyulang} / ${widget.existing.section}'),
              _value('Temuan', widget.existing.temuan),
              _value('Prioritas', widget.existing.prioritas),
            ]),
            const SizedBox(height: 14),
            _card('Foto Sesudah', [
              InkWell(
                onTap: _takePhoto,
                child: Container(
                  height: 180,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF1F4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _photo.isNotEmpty && File(_photo).existsSync()
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(File(_photo),
                              width: double.infinity, fit: BoxFit.cover),
                        )
                      : Text(_camera ? 'Membuka kamera...' : 'Ketuk untuk mengambil foto'),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            _card('Koordinat Realisasi', [
              _value('Koordinat', _coordinate),
              if (_accuracy != null) _value('Akurasi', _accuracy!),
              OutlinedButton.icon(
                onPressed: _readOnly || _locating ? null : _locate,
                icon: _locating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_rounded),
                label: Text(_locating ? 'Mengambil GPS...' : 'Ambil Koordinat'),
              ),
            ]),
            const SizedBox(height: 14),
            _card('Catatan Petugas', [
              TextField(
                controller: _notes,
                enabled: !_readOnly,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Catatan pekerjaan lapangan',
                ),
              ),
            ]),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _readOnly || _saving ? null : _finish,
              child: Text(_saving
                  ? 'Menyimpan...'
                  : _readOnly
                      ? 'WO Selesai'
                      : 'Simpan Selesai'),
            ),
          ],
        ),
      );

  Widget _card(String title, List<Widget> children) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      );

  Widget _value(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 115,
              child: Text(label,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            Expanded(child: Text(value.trim().isEmpty ? '-' : value)),
          ],
        ),
      );
}
