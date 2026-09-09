import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../services/api_service.dart';
import '../services/device_session_service.dart';
import '../services/local_auth_service.dart';
import '../services/sqlite_service.dart';
import '../theme/kopitiam_theme.dart';
import 'login_screen.dart';
import 'widgets/operation_result_dialog.dart';

class SettingsSessionSection extends StatefulWidget {
  final Map<String, dynamic> session;
  final bool showMasterGardu;
  const SettingsSessionSection({super.key, required this.session, this.showMasterGardu = true});
  @override State<SettingsSessionSection> createState() => _SettingsSessionSectionState();
}

class _SettingsSessionSectionState extends State<SettingsSessionSection> {
  Timer? _expiryTimer;
  bool _loggingOut = false;
  bool _downloadingGardu = false;
  double? _garduProgress;

  @override
  void initState() { super.initState(); _expiryTimer = Timer.periodic(const Duration(minutes: 1), (_) => _enforceOfflineExpiry()); WidgetsBinding.instance.addPostFrameCallback((_) => _enforceOfflineExpiry()); }
  @override void dispose() { _expiryTimer?.cancel(); super.dispose(); }

  Future<void> _downloadMasterGardu() async {
    if (_downloadingGardu) return;
    setState(() { _downloadingGardu = true; _garduProgress = null; });
    try {
      final response = await ApiService.getMasterGardu('${widget.session['token'] ?? ''}');
      if (response['success'] != true || response['rows'] is! List) throw StateError('${response['message'] ?? 'Master Gardu tidak valid.'}');
      final rows = response['rows'] as List;
      final db = await SqliteService.instance.database;
      final now = DateTime.now().toUtc().toIso8601String();
      if (mounted) setState(() => _garduProgress = rows.isEmpty ? 1 : 0);
      await db.transaction((txn) async {
        await txn.delete('master_data_rows', where: 'dataset = ?', whereArgs: ['Master_Gardu']);
        for (var i = 0; i < rows.length; i++) {
          final row = rows[i];
          if (row is! Map) continue;
          await txn.insert('master_data_rows', {'dataset': 'Master_Gardu', 'row_key': '$i', 'payload_json': jsonEncode(Map<String, dynamic>.from(row)), 'synced_at': now}, conflictAlgorithm: ConflictAlgorithm.replace);
          if (mounted) setState(() => _garduProgress = (i + 1) / rows.length);
        }
      });
      if (mounted) await showOperationResultDialog(context, success: true, title: 'Master Gardu Tersimpan', message: '${rows.length} data gardu siap digunakan offline.');
    } catch (e) {
      if (mounted) await showOperationResultDialog(context, success: false, title: 'Download Master Gardu Gagal', message: '$e');
    } finally {
      if (mounted) setState(() { _downloadingGardu = false; _garduProgress = null; });
    }
  }

  Future<void> _enforceOfflineExpiry() async { if (!mounted || !LocalAuthService.offlineSessionExpired(widget.session)) return; await _clear(); if (!mounted) return; Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute<void>(builder: (_) => const LoginScreen()), (_) => false); }
  Future<void> _logout() async { final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Keluar dari Kopitiam?'), content: const Text('Sesi perangkat dan akses offline akan dihapus.'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Keluar'))])); if (ok != true || !mounted) return; setState(() => _loggingOut = true); try { await ApiService.logoutPerangkat(token: '${widget.session['token'] ?? ''}'); } catch (_) { await DeviceSessionService.clear(); } finally { await _clear(); } if (!mounted) return; Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute<void>(builder: (_) => const LoginScreen()), (_) => false); }
  Future<void> _clear() async { await DeviceSessionService.clear(); await LocalAuthService.clear(); await (await SharedPreferences.getInstance()).clear(); }

  @override
  Widget build(BuildContext context) {
    final offline = widget.session['offlineLogin'] == true;
    return Column(children: [
      if (widget.showMasterGardu)
        Card(margin: const EdgeInsets.only(top: 14), child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Master Gardu', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Diunduh terpisah agar master utama lebih ringan.'),
          const SizedBox(height: 16),
          if (_garduProgress != null) ...[
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Menyimpan data gardu...', style: TextStyle(color: KopitiamColors.muted, fontSize: 12)), Text('${(_garduProgress! * 100).round()}%', style: const TextStyle(color: KopitiamColors.navy, fontSize: 12, fontWeight: FontWeight.w800))]),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: _garduProgress),
            const SizedBox(height: 12),
          ],
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _downloadingGardu ? null : _downloadMasterGardu, icon: _downloadingGardu ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: KopitiamColors.surface)) : const Icon(Icons.domain_rounded), label: Text(_downloadingGardu ? 'Mengunduh...' : 'Download Master Gardu'))),
        ]))),
      Card(margin: const EdgeInsets.only(top: 14), child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Akun & Sesi', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)), const SizedBox(height: 6), Text(offline ? 'Mode offline aktif, maksimal 24 jam sejak verifikasi online.' : 'Keluar akan mencabut token perangkat dan akses offline.'), const SizedBox(height: 16), SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _loggingOut ? null : _logout, icon: const Icon(Icons.logout_rounded), label: Text(_loggingOut ? 'Keluar...' : 'Log out')))]))),
    ]);
  }
}
