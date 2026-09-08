import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kopitiam_mobile/models/har_execution.dart';
import 'package:kopitiam_mobile/services/har_execution_repository.dart';

class HarMemoryDb implements Database,Transaction {
  final rows=<Map<String,Object?>>[];
  bool reject=false;
  @override Future<void> execute(String sql,[List<Object?>? arguments])async{}
  @override Future<List<Map<String,Object?>>> query(String table,{bool? distinct,List<String>? columns,String? where,List<Object?>? whereArgs,String? groupBy,String? having,String? orderBy,int? limit,int? offset})async{
    if(table=='master_data_rows')return [{'payload_json':jsonEncode({'Kode Material':'M1','Nama Material':'Isolator','Satuan Material':'Pcs','Status Baris':'Aktif'})}];
    return rows.where((r)=>r['owner']==whereArgs![0]&&r['jenis_wo']==whereArgs[1]&&(whereArgs.length<3||r['kode_wo']==whereArgs[2])).map((r)=>Map<String,Object?>.from(r)).toList();
  }
  @override Future<int> insert(String table,Map<String,Object?> values,{String? nullColumnHack,ConflictAlgorithm? conflictAlgorithm})async{
    if(reject)throw StateError('Disk penuh');
    rows.removeWhere((r)=>r['owner']==values['owner']&&r['jenis_wo']==values['jenis_wo']&&r['kode_wo']==values['kode_wo']);rows.add(Map.of(values));return 1;
  }
  @override Future<T> transaction<T>(Future<T> Function(Transaction) action,{bool? exclusive})async{
    final snapshot=rows.map((r)=>Map<String,Object?>.from(r)).toList();try{return await action(this);}catch(_){rows..clear()..addAll(snapshot);rethrow;}
  }
  @override dynamic noSuchMethod(Invocation invocation)=>super.noSuchMethod(invocation);
}
void main(){
  const session={'username':'koba.harjar','subTim':'Har Jar','kodeUlp':'16140','token':'token'};
  final header={'Kode WO':'WO1','Kode Temuan':'T1','Jenis WO':HarExecution.jar,'Status WO':'Menunggu','Kode ULP':'16140','Koordinat':'-2,106','Folder Path':'parent/'};
  Future<Map<String,dynamic>> download(String type,String token)async=>{'success':true,'rows':[header]};
  test('start timestamp is written once; restart and download preserve local jobs',()async{
    final db=HarMemoryDb();final repo=HarExecutionRepository(session,database:db,downloadApi:download);
    expect(await repo.download(HarExecution.jar),1);await repo.start(HarExecution.jar,'WO1');final start=(await repo.get(HarExecution.jar,'WO1'))!.value('Waktu Mulai');await repo.start(HarExecution.jar,'WO1');
    await repo.addJob(HarExecution.jar,'WO1',description:'Ganti isolator',quantity:2,set:'Set',materials:[{'Kode Material':'M1','Jumlah':2,'Kepemilikan':'PLN'}]);
    final restart=HarExecutionRepository(session,database:db,downloadApi:download);expect(await restart.download(HarExecution.jar),0);final item=(await restart.get(HarExecution.jar,'WO1'))!;
    expect(item.value('Waktu Mulai'),start);expect(item.jobs.single['Jumlah'],2);expect(item.materials.single['Satuan'],'Pcs');expect(item.materials.single['Kode Pekerjaan'],item.jobs.single['Kode Pekerjaan']);expect(item.value('Folder Path'),'parent/');
    final other=HarExecutionRepository({...session,'username':'other.harjar'},database:db);expect(await other.list(HarExecution.jar),isEmpty);
  });
  test('invalid material and failed local commit cannot leave orphan jobs',()async{
    final db=HarMemoryDb();final repo=HarExecutionRepository(session,database:db,downloadApi:download);await repo.download(HarExecution.jar);await repo.start(HarExecution.jar,'WO1');
    await expectLater(repo.addJob(HarExecution.jar,'WO1',description:'A',quantity:1,set:'Set',materials:[{'Kode Material':'missing','Jumlah':1,'Kepemilikan':'PLN'}]),throwsStateError);
    db.reject=true;await expectLater(repo.addJob(HarExecution.jar,'WO1',description:'A',quantity:1,set:'Set',materials:[]),throwsStateError);db.reject=false;
    expect((await repo.get(HarExecution.jar,'WO1'))!.jobs,isEmpty);
  });
  test('failed ACK preserves queue; retry uses same job ID and success retains history',()async{
    final db=HarMemoryDb();bool fail=true;final calls=<List<Map<String,dynamic>>>[];
    final repo=HarExecutionRepository(session,database:db,downloadApi:download,sendApi:(type,token,rows)async{calls.add(rows);return fail?{'success':false,'message':'Network'}:{'success':true,'accepted':['WO1']};});
    await repo.download(HarExecution.jar);await repo.start(HarExecution.jar,'WO1');await repo.addJob(HarExecution.jar,'WO1',description:'A',quantity:1,set:'Set',materials:[]);
    await repo.sync(HarExecution.jar);expect((await repo.get(HarExecution.jar,'WO1'))!.dirty,true);fail=false;await repo.sync(HarExecution.jar);final item=(await repo.get(HarExecution.jar,'WO1'))!;
    expect(item.dirty,false);expect(item.jobs.length,1);expect((calls.first.single['jobs'] as List).first['Kode Pekerjaan'],(calls.last.single['jobs'] as List).first['Kode Pekerjaan']);
  });
  test('job edits during upload keep the new revision dirty',()async{
    final db=HarMemoryDb();late HarExecutionRepository repo;
    repo=HarExecutionRepository(session,database:db,downloadApi:download,sendApi:(type,token,rows)async{await repo.addJob(type,'WO1',description:'New',quantity:1,set:'Set',materials:[]);return {'success':true,'accepted':['WO1']};});
    await repo.download(HarExecution.jar);await repo.start(HarExecution.jar,'WO1');await repo.sync(HarExecution.jar);expect((await repo.get(HarExecution.jar,'WO1'))!.dirty,true);
  });
}
