import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../services/api_service.dart';
import '../../services/sqlite_service.dart';
import '../../theme/kopitiam_theme.dart';

abstract final class MasterSyncStatus {
  static const pending = 'pending';
  static const syncing = 'syncing';
  static const synced = 'synced';
  static const failed = 'failed';
}

class MasterDatasetState {
  final String key;
  final String label;
  final String status;
  final String error;

  const MasterDatasetState({
    required this.key,
    required this.label,
    this.status = MasterSyncStatus.pending,
    this.error = '',
  });

  MasterDatasetState copyWith({String? status, String? error}) =>
      MasterDatasetState(
        key: key,
        label: label,
        status: status ?? this.status,
        error: error ?? this.error,
      );
}

typedef GeneralMasterFetcher = Future<Map<String, dynamic>> Function(String token);
typedef GarduMasterFetcher = Future<Map<String, dynamic>> Function(String token);

class MasterDataAccordion extends StatefulWidget {
  final String token;
  final GeneralMasterFetcher? fetchGeneral;
  final GarduMasterFetcher? fetchGardu;
  final Database? database;

  const MasterDataAccordion({
    super.key,
    required this.token,
    this.fetchGeneral,
    this.fetchGardu,
    this.database,
  });

  @override
  State<MasterDataAccordion> createState() => _MasterDataAccordionState();
}

class _MasterDataAccordionState extends State<MasterDataAccordion> {
  static const definitions = <MapEntry<String, String>>[
    MapEntry('User_App_Mobile', 'Master User & Akses'),
    MapEntry('Master_Penyulang', 'Master Penyulang'),
    MapEntry('Master_Keypoint', 'Master Keypoint'),
    MapEntry('Master_Temuan', 'Master Temuan'),
    MapEntry('Jenis Pohon', 'Master Jenis Pohon'),
    MapEntry('Master_Material', 'Master Material'),
    MapEntry('Master_Pekerjaan_Har', 'Master Pekerjaan Har'),
    MapEntry('Master_Gardu', 'Master Gardu'),
  ];

  late List<MasterDatasetState> datasets = definitions
      .map((entry) => MasterDatasetState(key: entry.key, label: entry.value))
      .toList();
  final selected = <String>{};
  bool expanded = false;
  bool busy = false;
  double progress = 0;
  String progressLabel = '';

  Future<Database> get db async => widget.database ?? SqliteService.instance.database;
  GeneralMasterFetcher get fetchGeneral => widget.fetchGeneral ?? ApiService.getMasterData;
  GarduMasterFetcher get fetchGardu => widget.fetchGardu ?? ApiService.getMasterGardu;

  @override
  void initState() {
    super.initState();
    _loadStatuses();
  }

  Future<void> _loadStatuses() async {
    final database = await db;
    final rows = await database.query('sync_metadata');
    final metadata = {for (final row in rows) '${row['key']}': row};
    if (!mounted) return;
    setState(() {
      datasets = datasets.map((item) {
        final row = metadata[item.key];
        if (row == null) return item;
        final success = '${row['status']}' == 'success';
        return item.copyWith(
          status: success ? MasterSyncStatus.synced : MasterSyncStatus.failed,
          error: '${row['error_message'] ?? ''}',
        );
      }).toList();
      selected.addAll(
        datasets
            .where((item) => item.status != MasterSyncStatus.synced)
            .map((item) => item.key),
      );
    });
  }

  int _index(String key) => datasets.indexWhere((item) => item.key == key);

  void _setStatus(String key, String status, {String error = ''}) {
    final index = _index(key);
    if (index < 0 || !mounted) return;
    setState(() => datasets[index] = datasets[index].copyWith(status: status, error: error));
  }

  Future<void> _persist(String key, List rows) async {
    final database = await db;
    final now = DateTime.now().toUtc().toIso8601String();
    await database.transaction((txn) async {
      await txn.delete('master_data_rows', where: 'dataset = ?', whereArgs: [key]);
      for (var index = 0; index < rows.length; index++) {
        final row = rows[index];
        if (row is! Map) continue;
        await txn.insert(
          'master_data_rows',
          {
            'dataset': key,
            'row_key': '$index',
            'payload_json': jsonEncode(Map<String, dynamic>.from(row)),
            'synced_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await txn.insert(
        'sync_metadata',
        {
          'key': key,
          'synced_at': now,
          'row_count': rows.length,
          'status': 'success',
          'error_message': '',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> _persistFailure(String key, Object error) async {
    final database = await db;
    await database.insert(
      'sync_metadata',
      {
        'key': key,
        'synced_at': DateTime.now().toUtc().toIso8601String(),
        'row_count': 0,
        'status': 'failed',
        'error_message': '$error',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _sync(Iterable<String> keys) async {
    if (busy) return;
    final targets = keys.toSet();
    if (targets.isEmpty) return;
    setState(() {
      busy = true;
      expanded = true;
      progress = 0;
      for (final key in targets) {
        final index = _index(key);
        datasets[index] = datasets[index].copyWith(status: MasterSyncStatus.syncing, error: '');
      }
    });

    var completed = 0;
    final generalKeys = targets.where((key) => key != 'Master_Gardu').toList();
    if (generalKeys.isNotEmpty) {
      try {
        final response = await fetchGeneral(widget.token);
        if (response['success'] != true || response['datasets'] is! Map) {
          throw StateError('${response['message'] ?? 'Master Data tidak valid.'}');
        }
        final payload = Map<String, dynamic>.from(response['datasets']);
        for (final key in generalKeys) {
          try {
            final rows = payload[key];
            if (rows is! List) throw StateError('Dataset tidak tersedia.');
            if (mounted) setState(() => progressLabel = 'Sinkronisasi ${datasets[_index(key)].label}');
            await _persist(key, rows);
            _setStatus(key, MasterSyncStatus.synced);
          } catch (error) {
            await _persistFailure(key, error);
            _setStatus(key, MasterSyncStatus.failed, error: '$error');
          }
          completed++;
          if (mounted) setState(() => progress = completed / targets.length);
        }
      } catch (error) {
        for (final key in generalKeys) {
          await _persistFailure(key, error);
          _setStatus(key, MasterSyncStatus.failed, error: '$error');
          completed++;
          if (mounted) setState(() => progress = completed / targets.length);
        }
      }
    }

    if (targets.contains('Master_Gardu')) {
      const key = 'Master_Gardu';
      try {
        if (mounted) setState(() => progressLabel = 'Sinkronisasi Master Gardu');
        final response = await fetchGardu(widget.token);
        if (response['success'] != true || response['rows'] is! List) {
          throw StateError('${response['message'] ?? 'Master Gardu tidak valid.'}');
        }
        await _persist(key, response['rows'] as List);
        _setStatus(key, MasterSyncStatus.synced);
      } catch (error) {
        await _persistFailure(key, error);
        _setStatus(key, MasterSyncStatus.failed, error: '$error');
      }
      completed++;
      if (mounted) setState(() => progress = completed / targets.length);
    }

    if (mounted) {
      setState(() {
        busy = false;
        selected.removeWhere(targets.contains);
      });
    }
  }

  String get summaryStatus {
    if (datasets.any((item) => item.status == MasterSyncStatus.failed)) return 'GAGAL';
    if (datasets.any((item) => item.status == MasterSyncStatus.syncing)) return 'PROSES';
    if (datasets.every((item) => item.status == MasterSyncStatus.synced)) return 'SINKRON';
    return 'BELUM SINKRON';
  }

  Color get summaryColor => switch (summaryStatus) {
        'SINKRON' => KopitiamColors.success,
        'GAGAL' => KopitiamColors.danger,
        'PROSES' => KopitiamColors.ocean,
        _ => KopitiamColors.warning,
      };

  Color get summarySoft => switch (summaryStatus) {
        'SINKRON' => KopitiamColors.successSoft,
        'GAGAL' => KopitiamColors.dangerSoft,
        'PROSES' => KopitiamColors.cyanSoft,
        _ => KopitiamColors.warningSoft,
      };

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('master-data-accordion'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: KopitiamColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE4D5AC)),
          boxShadow: const [
            BoxShadow(color: Color(0x17071F33), blurRadius: 28, offset: Offset(0, 12)),
          ],
        ),
        child: Stack(
          children: [
            const Positioned(
              left: 70,
              right: 70,
              top: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, KopitiamColors.gold, Colors.transparent],
                  ),
                ),
                child: SizedBox(height: 3),
              ),
            ),
            Column(
              children: [
                InkWell(
                  onTap: busy ? null : () => setState(() => expanded = !expanded),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: KopitiamColors.cyanSoft,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(Icons.cloud_download_rounded, color: Color(0xFF004D8C), size: 27),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Master Data', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                              SizedBox(height: 4),
                              Text('Kelola data untuk penggunaan offline', style: TextStyle(color: KopitiamColors.muted, fontSize: 11)),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(color: summarySoft, borderRadius: BorderRadius.circular(100)),
                              child: Text(summaryStatus, style: TextStyle(color: summaryColor, fontSize: 9, fontWeight: FontWeight.w900)),
                            ),
                            const SizedBox(height: 5),
                            AnimatedRotation(
                              turns: expanded ? .5 : 0,
                              duration: const Duration(milliseconds: 300),
                              curve: const Cubic(0.16, 1, 0.3, 1),
                              child: const Icon(Icons.keyboard_arrow_down_rounded, color: KopitiamColors.muted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 360),
                  firstCurve: const Cubic(0.16, 1, 0.3, 1),
                  secondCurve: const Cubic(0.16, 1, 0.3, 1),
                  crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: _details(),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _details() => Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          children: [
            const Divider(),
            Row(
              children: [
                const Expanded(child: Text('Pilih Master Data yang ingin disinkronkan', style: TextStyle(color: KopitiamColors.muted, fontSize: 11))),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                            selected
                              ..clear()
                              ..addAll(datasets.where((item) => item.status != MasterSyncStatus.synced).map((item) => item.key));
                          }),
                  child: const Text('Pilih semua'),
                ),
              ],
            ),
            for (final item in datasets) _datasetRow(item),
            if (busy) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(color: KopitiamColors.surfaceStrong, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(progressLabel, style: const TextStyle(color: KopitiamColors.muted, fontSize: 10))),
                        Text('${(progress * 100).round()}%', style: const TextStyle(color: KopitiamColors.navy, fontSize: 10, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: progress),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy || selected.isEmpty ? null : () => _sync(selected),
                    child: Text('Sinkron Terpilih${selected.isEmpty ? '' : ' (${selected.length})'}'),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : () => _sync(datasets.map((item) => item.key)),
                    child: const Text('Sinkron Semua'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _datasetRow(MasterDatasetState item) {
    final syncing = item.status == MasterSyncStatus.syncing;
    final failed = item.status == MasterSyncStatus.failed;
    final synced = item.status == MasterSyncStatus.synced;
    final color = failed
        ? KopitiamColors.danger
        : synced
            ? KopitiamColors.success
            : syncing
                ? KopitiamColors.ocean
                : KopitiamColors.warning;
    final label = failed
        ? 'GAGAL'
        : synced
            ? 'SINKRON'
            : syncing
                ? 'PROSES'
                : 'BELUM SINKRON';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: KopitiamColors.line))),
      child: Row(
        children: [
          if (!failed && !syncing && !synced)
            Checkbox(
              value: selected.contains(item.key),
              onChanged: busy
                  ? null
                  : (value) => setState(() => value == true ? selected.add(item.key) : selected.remove(item.key)),
              visualDensity: VisualDensity.compact,
            )
          else
            const SizedBox(width: 40),
          Expanded(child: Text(item.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
          if (syncing)
            const Padding(
              padding: EdgeInsets.only(right: 7),
              child: SizedBox.square(dimension: 13, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900)),
          if (failed) ...[
            const SizedBox(width: 7),
            TextButton.icon(
              onPressed: busy ? null : () => _sync([item.key]),
              icon: const Icon(Icons.refresh_rounded, size: 15),
              label: const Text('Coba Ulang'),
              style: TextButton.styleFrom(foregroundColor: KopitiamColors.danger, textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          ],
        ],
      ),
    );
  }
}
