import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopitiam_mobile/screens/widgets/master_data_accordion.dart';
import 'package:sqflite/sqflite.dart';

class MasterMemoryDb implements Database, Transaction {
  final metadata = <String, Map<String, Object?>>{};
  final rows = <Map<String, Object?>>[];

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    if (table == 'sync_metadata') return metadata.values.toList();
    return rows;
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    if (table == 'sync_metadata') {
      metadata['${values['key']}'] = Map<String, Object?>.from(values);
    } else {
      rows.add(Map<String, Object?>.from(values));
    }
    return 1;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    if (table == 'master_data_rows' && whereArgs?.isNotEmpty == true) {
      rows.removeWhere((row) => row['dataset'] == whereArgs!.first);
    }
    return 1;
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) => action(this);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, Object?> metadataRow(String key, String status) => {
      'key': key,
      'status': status,
      'error_message': status == 'failed' ? 'Jaringan terputus' : '',
    };

Future<void> openAccordion(WidgetTester tester) async {
  await tester.tap(find.text('Master Data'));
  await tester.pumpAndSettle();
}

void main() {
  test('status constants cover every visual state', () {
    expect(
      {
        MasterSyncStatus.pending,
        MasterSyncStatus.syncing,
        MasterSyncStatus.synced,
        MasterSyncStatus.failed,
      },
      {'pending', 'syncing', 'synced', 'failed'},
    );
  });

  testWidgets('renders Belum Sinkron, Sinkron, Gagal, and Coba Ulang', (
    tester,
  ) async {
    final db = MasterMemoryDb()
      ..metadata['Master_Penyulang'] = metadataRow('Master_Penyulang', 'success')
      ..metadata['Master_Gardu'] = metadataRow('Master_Gardu', 'failed');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MasterDataAccordion(token: 'token', database: db),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await openAccordion(tester);

    expect(find.text('BELUM SINKRON'), findsWidgets);
    expect(find.text('SINKRON'), findsWidgets);
    expect(find.text('GAGAL'), findsWidgets);
    expect(find.text('Coba Ulang'), findsOneWidget);
  });

  testWidgets('Coba Ulang changes a failed dataset to Sinkron', (tester) async {
    final db = MasterMemoryDb()
      ..metadata['Master_Gardu'] = metadataRow('Master_Gardu', 'failed');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MasterDataAccordion(
              token: 'token',
              database: db,
              fetchGardu: (_) async => {
                'success': true,
                'rows': [
                  {'GARDU': 'G1'},
                ],
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await openAccordion(tester);
    await tester.tap(find.text('Coba Ulang'));
    await tester.pumpAndSettle();

    expect(db.metadata['Master_Gardu']?['status'], 'success');
    expect(find.text('Coba Ulang'), findsNothing);
    expect(find.text('SINKRON'), findsWidgets);
  });
}
