import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopitiam_mobile/models/har_execution.dart';
import 'package:kopitiam_mobile/services/har_execution_repository.dart';
import 'package:kopitiam_mobile/screens/har_execution_screen.dart';
import 'package:kopitiam_mobile/screens/har_job_form_screen.dart';
import 'package:kopitiam_mobile/theme/kopitiam_theme.dart';

class DemoHarRepo extends HarExecutionRepository {
  DemoHarRepo():super({'username':'koba.harjar','subTim':'Har Jar','kodeUlp':'16140'});
  HarExecution item=HarExecution(header:{'Kode WO':'HAR-001','Kode Temuan':'INS.TO-001','Jenis WO':HarExecution.jar,'Status WO':'Menunggu','Penyulang':'Koba','Section':'A-B','Segmen':'A1','Temuan':'Isolator','Prioritas':'Mayor'});
  int starts=0,jobsSaved=0;
  List<Map<String,dynamic>> savedMaterials=[];
  @override Future<List<HarExecution>> list(String type)async=>[item];
  @override Future<HarExecution?> get(String type,String code)async=>item;
  @override Future<void> start(String type,String code)async{if(item.started)return;starts++;item=item.change(header:{...item.header,'Status WO':HarExecution.progress,'Waktu Mulai':'09:00'});}
  @override Future<List<HarMaterial>> materialMaster()async=>[const HarMaterial('M1','Isolator','Pcs','Aktif')];
  @override Future<void> addJob(String type,String code,{required String description,required double quantity,required String set,required List<Map<String,dynamic>> materials})async{jobsSaved++;savedMaterials=materials;}
}
void main(){
  test('scope resolver distinguishes exact Har Jar, Har Du and general Har',(){expect(HarExecution.allowedTypes({'subTim':'Har Jar','username':'koba.harjar'}),[HarExecution.jar]);expect(HarExecution.allowedTypes({'subTim':'Har Du'}),[HarExecution.du]);expect(HarExecution.allowedTypes({'subTim':'Hartek'}),[HarExecution.jar,HarExecution.du]);expect(HarExecution.allowedTypes({'subTim':'Inspeksi Jaringan'}),isEmpty);});
  test('round trip retains jobs, material, errors and pending upload',(){final item=HarExecution(header:{'Kode WO':'WO1','Jenis WO':HarExecution.jar},jobs:[{'Kode Pekerjaan':'P1'}],materials:[{'Kode Pekerjaan':'P1','Satuan':'Pcs'}],dirty:true,error:'network',revision:2);final restored=HarExecution.decode(jsonEncode(item.toJson()));expect(restored.materials.single['Satuan'],'Pcs');expect(restored.jobs.single['Kode Pekerjaan'],'P1');expect(restored.dirty,true);expect(restored.revision,2);});
  test('material lookup uses supplied exact headers and excludes explicit inactive rows',(){final m=HarMaterial.fromMap({'Kode Material':'M1','Nama Material':'Isolator','Satuan Material':'Pcs','Status Baris':'Aktif'});expect(m.unit,'Pcs');expect(m.available,true);expect(const HarMaterial('M2','A','Meter','Nonaktif').available,false);expect(const HarMaterial('M3','A','','Aktif').available,false);});
  test('generated IDs are stable-format and distinct',(){final a=HarExecution.newId('PKJ'),b=HarExecution.newId('PKJ');expect(a,matches(RegExp(r'^PKJ-[a-f0-9]{32}$')));expect(a,isNot(b));});
  testWidgets('No leaves WO untouched; Yes starts only, second card tap opens tabs', (tester)async{
    final repo=DemoHarRepo();await tester.pumpWidget(MaterialApp(theme:KopitiamTheme.light,home:HarExecutionScreen(sesi:repo.session,repository:repo)));await tester.pumpAndSettle();
    await tester.tap(find.text('Work Order'));await tester.pumpAndSettle();
    await tester.tap(find.text('HAR-001'));await tester.pumpAndSettle();expect(find.textContaining('kode: HAR-001'),findsOneWidget);await tester.tap(find.text('Tidak'));await tester.pumpAndSettle();expect(repo.starts,0);
    await tester.tap(find.text('HAR-001'));await tester.pumpAndSettle();await tester.tap(find.text('Ya'));await tester.pumpAndSettle();expect(repo.starts,1);expect(find.byType(HarWoDetailScreen),findsNothing);
    await tester.tap(find.text('HAR-001'));await tester.pumpAndSettle();expect(find.text('Detail WO'),findsOneWidget);expect(find.byType(FloatingActionButton),findsNothing);await tester.tap(find.text('Pekerjaan'));await tester.pumpAndSettle();expect(find.byType(FloatingActionButton),findsOneWidget);expect(repo.starts,1);
  });
  testWidgets('material row has only name, quantity with lookup unit, ownership', (tester)async{
    final repo=DemoHarRepo();await tester.pumpWidget(MaterialApp(theme:KopitiamTheme.light,home:HarJobFormScreen(item:repo.item,repository:repo)));await tester.pumpAndSettle();await tester.tap(find.text('Material'));await tester.pumpAndSettle();await tester.tap(find.byType(FloatingActionButton));await tester.pumpAndSettle();
    await tester.tap(find.text('Nama Material'));await tester.pumpAndSettle();await tester.tap(find.text('Isolator (M1)').last);await tester.pumpAndSettle();expect(find.text('Jumlah Material (Pcs)'),findsOneWidget);expect(find.text('Satuan otomatis: Pcs'),findsOneWidget);expect(find.byType(DropdownButtonFormField<String>),findsNWidgets(2));
  });
}
