import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopitiam_mobile/models/har_execution.dart';
import 'package:kopitiam_mobile/services/har_execution_repository.dart';
import 'package:kopitiam_mobile/screens/har_execution_screen.dart';
import 'package:kopitiam_mobile/screens/har_job_form_screen.dart';
import 'package:kopitiam_mobile/widgets/har_execution_card.dart';
import 'package:kopitiam_mobile/theme/kopitiam_theme.dart';

class DemoHarRepo extends HarExecutionRepository {
  DemoHarRepo({Map<String, dynamic>? session}) : super(session ?? {'username': 'koba.harjar', 'subTim': 'Har Jar', 'kodeUlp': '16140'});
  HarExecution item = HarExecution(header: {'Kode WO': 'HAR-001', 'Kode Temuan': 'INS.TO-001', 'Jenis WO': HarExecution.jar, 'Status WO': 'Menunggu', 'Penyulang': 'Koba', 'Section': 'A-B', 'Segmen': 'A1', 'Temuan': 'Isolator', 'Prioritas': 'Mayor'});
  int starts = 0;
  bool emptyDownload = false;
  @override Future<List<HarExecution>> list(String type) async => [item];
  @override Future<List<HarExecution>> listAll() async => [item];
  @override Future<HarExecution?> get(String type, String code) async => item;
  @override Future<HarMasterState> masterState() async => const HarMasterState(false, null);
  @override Future<HarDownloadResult> downloadAssigned() async => HarDownloadResult(emptyDownload ? 0 : 1, emptyDownload ? 0 : 1, [HarExecution.jar]);
  @override Future<void> start(String type, String code) async { if (item.started) return; starts++; item = item.change(header: {...item.header, 'Status WO': HarExecution.progress, 'Waktu Mulai': '09:00'}); }
  @override Future<List<HarMaterial>> materialMaster() async => [const HarMaterial('M1', 'Isolator', 'Pcs', 'Aktif')];
  @override Future<void> addJob(String type, String code, {required String description, required double quantity, required String set, required List<Map<String, dynamic>> materials}) async {}
  @override Future<String> syncAll() async => '0 WO tersinkron';
}

Future<void> openWorkTab(WidgetTester tester) async {
  await tester.tap(find.text('Work Order').last);
  await tester.pumpAndSettle();
}

Widget harScreen(DemoHarRepo repo) => MaterialApp(theme: KopitiamTheme.light, home: HarExecutionScreen(sesi: repo.session, repository: repo, networkProbe: () async => true));

void main() {
  test('role resolver: generic Har gets both, specific gets one, Admin is marked', () { expect(HarExecution.allowedTypes({'subTim': 'Har', 'username': '16130.Har'}), [HarExecution.jar, HarExecution.du]); expect(HarExecution.allowedTypes({'subTim': 'Har Jar', 'username': 'x.harjar'}), [HarExecution.jar]); expect(HarExecution.allowedTypes({'subTim': 'Har Du', 'username': 'x.hardu'}), [HarExecution.du]); expect(HarExecution.isAdmin({'role': 'Admin'}), true); });
  test('round trip retains execution state', () { final item = HarExecution(header: {'Kode WO': 'WO1', 'Jenis WO': HarExecution.jar}, jobs: [{'Kode Pekerjaan': 'P1'}], materials: [{'Satuan': 'Pcs'}], dirty: true, error: 'network', revision: 2); final restored = HarExecution.decode(jsonEncode(item.toJson())); expect(restored.materials.single['Satuan'], 'Pcs'); expect(restored.dirty, true); });
  testWidgets('unified screen exposes the Work Order tab', (tester) async { final repo = DemoHarRepo(); await tester.pumpWidget(harScreen(repo)); await tester.pump(const Duration(milliseconds: 100)); await openWorkTab(tester); expect(find.text('Work Order Har'), findsOneWidget); });
  testWidgets('admin does not see Download WO', (tester) async { final repo = DemoHarRepo(session: {'username': 'admin', 'role': 'Admin', 'kodeUlp': '16140'}); await tester.pumpWidget(harScreen(repo)); await tester.pump(const Duration(milliseconds: 100)); expect(find.text('Download WO'), findsNothing); });
  testWidgets('confirmation starts once; second tap opens details', (tester) async { final repo = DemoHarRepo(); await tester.pumpWidget(harScreen(repo)); await tester.pump(const Duration(milliseconds: 100)); await openWorkTab(tester); await tester.tap(find.byType(HarExecutionCard).first); await tester.pump(const Duration(milliseconds: 100)); await tester.tap(find.text('Ya')); await tester.pump(const Duration(milliseconds: 100)); expect(repo.starts, 1); await tester.tap(find.byType(HarExecutionCard).first); await tester.pump(const Duration(milliseconds: 100)); expect(find.text('Detail WO'), findsOneWidget); });
  testWidgets('material lookup still hides manual unit field', (tester) async { final repo = DemoHarRepo(); await tester.pumpWidget(MaterialApp(theme: KopitiamTheme.light, home: HarJobFormScreen(item: repo.item, repository: repo))); await tester.pumpAndSettle(); await tester.tap(find.text('Material')); await tester.pumpAndSettle(); await tester.tap(find.byType(FloatingActionButton)); await tester.pumpAndSettle(); await tester.tap(find.text('Nama Material')); await tester.pumpAndSettle(); await tester.tap(find.text('Isolator (M1)').last); await tester.pumpAndSettle(); expect(find.text('Jumlah Material (Pcs)'), findsOneWidget); expect(find.text('Satuan otomatis: Pcs'), findsOneWidget); });
}
