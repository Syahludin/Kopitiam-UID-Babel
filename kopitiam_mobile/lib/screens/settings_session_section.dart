import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../services/api_service.dart';
import '../services/device_session_service.dart';
import '../services/local_auth_service.dart';
import '../services/sqlite_service.dart';
import 'login_screen.dart';
import 'widgets/operation_result_dialog.dart';

class SettingsSessionSection extends StatefulWidget {
  final Map<String, dynamic> session;
  const SettingsSessionSection({super.key, required this.session});

  @override
  State<SettingsSessionSection> createState() => _SettingsSessionSectionState();
}

class _SettingsSessionSectionState extends State<SettingsSessionSection> {
  Timer? _expiryTimer;
  bool _loggingOut = false;
  bool _downloadingGardu = false;

  @override
  void initState() {
    super.initState();
    _expiryTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _enforceOfflineExpiry(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _enforceOfflineExpiry());
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _downloadMasterGardu() async {
    if (_downloadingGardu) return;
    setState(() => _downloadingGardu = true);
    try {
      final response = await ApiService.getMasterGardu(
        '${widget.session['token'] ?? ''}',
      );
      if (response['success'] != true || response['rows'] is! List) {
        throw StateError('${response['message'] ?? 'Master Gardu tidak valid.'}');
      }
      final rows = response['rows'] as List;
      final db = await SqliteService.instance.database;
      final now = DateTime.now().toUtc().toIso8601String();
      await db.transaction((txn) async {
        await txn.delete(
          'master_data_rows',
          where: 'dataset = ?',
          whereArgs: ['Master_Gardu'],
        );
        final batch = txn.batch();
        for (var i = 0; i < rows.length; i++) {
          final row = rows[i];
          if (row is! Map) continue;
          batch.insert(
            'master_data_rows',
            {
              'dataset': 'Master_Gardu',
              'row_key': i.toString(),
              'payload_json': jsonEncode(Map<String, dynamic>.from(row)),
              'synced_at': now,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
        await txn.insert(
          'sync_metadata',
          {
            'key': 'Master_Gardu',
            'synced_at': now,
            'row_count': rows.length,
            'status': 'success',
            'error_message': '',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });
      if (mounted) {
        await showOperationResultDialog(
          context,
          success: true,
          title: 'Master Gardu Tersimpan',
          message: '${rows.length} data gardu siap digunakan offline.',
        );
      }
    } catch (error) {
      if (mounted) {
        await showOperationResultDialog(
          context,
          success: false,
          title: 'Download Master Gardu Gagal',
          message: error.toString().replaceFirst('Bad state: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingGardu = false);
    }
  }

  Future<void> _enforceOfflineExpiry() async {
    if (!mounted || !LocalAuthService.offlineSessionExpired(widget.session)) return;
    await _clearLocalSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari Kopitiam?'),
        content: const Text('Sesi perangkat dan akses offline akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loggingOut = true);
    try {
      await ApiService.logoutPerangkat(
        token: '${widget.session['token'] ?? ''}',
      );
    } catch (_) {
      await DeviceSessionService.clear();
    } finally {
      await _clearLocalSession();
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _clearLocalSession() async {
    await DeviceSessionService.clear();
    await LocalAuthService.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  @override
  Widget build(BuildContext context) {
    final offline = widget.session['offlineLogin'] == true;
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.only(top: 14),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Master Gardu',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Diunduh terpisah agar master utama lebih ringan dan cepat.',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _downloadingGardu ? null : _downloadMasterGardu,
                    icon: _downloadingGardu
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.domain_rounded),
                    label: Text(
                      _downloadingGardu
                          ? 'Mengunduh Master Gardu...'
                          : 'Download Master Gardu',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.only(top: 14),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Akun & Sesi',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  offline
                      ? 'Mode offline aktif, maksimal 24 jam sejak verifikasi online.'
                      : 'Keluar akan mencabut token perangkat dan akses offline.',
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _loggingOut ? null : _logout,
                    icon: _loggingOut
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.logout_rounded),
                    label: Text(_loggingOut ? 'Keluar...' : 'Log out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
