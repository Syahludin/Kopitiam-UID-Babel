import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import '../models/temuan_inspeksi.dart';
import '../models/wo_insjar.dart';
import 'api_service.dart';
import 'sqlite_service.dart';

class TemuanRepository {
  final _db=SqliteService.instance;
  Future<List<TemuanInspeksi>> untukWo(String kode) async {final d=await _db.database;final r=await d.query('temuan_inspeksi',where:'kode_wo=?',whereArgs:[kode],orderBy:'kode_temuan');return r.map(TemuanInspeksi.fromMap).toList();}
  Future<String> kodeBaru(String kodeWo) async {final d=await _db.database;final r=await d.rawQuery('SELECT kode_temuan FROM temuan_inspeksi WHERE kode_wo=? ORDER BY kode_temuan DESC LIMIT 1',[kodeWo]);var n=0;if(r.isNotEmpty){n=int.tryParse('${r.first['kode_temuan']}'.split('.TO-').last)??0;}return '$kodeWo.TO-${(n+1).toString().padLeft(3,'0')}';}
  Future<void> simpan(TemuanInspeksi t) async {final d=await _db.database;await d.insert('temuan_inspeksi',t.toMap(),conflictAlgorithm:ConflictAlgorithm.replace);}
  Future<void> unduh(String token,String kodeWo) async {final res=await ApiService.getTemuan(token,kodeWo);if(res['success']!=true||res['rows'] is! List)return;final d=await _db.database;for(final x in res['rows']){if(x is Map){final t=TemuanInspeksi.fromRemote(Map<String,dynamic>.from(x));await d.insert('temuan_inspeksi',t.toMap(),conflictAlgorithm:ConflictAlgorithm.ignore);}}}
  Future<void> sinkron(String token) async {final d=await _db.database;final rows=await d.query('temuan_inspeksi',where:'is_dirty=1');for(final row in rows){final t=TemuanInspeksi.fromMap(row);final data=t.toRemote();if(t.fotoTemuan.isNotEmpty&&File(t.fotoTemuan).existsSync()){data['fotoTemuanBase64']=base64Encode(await File(t.fotoTemuan).readAsBytes());}if(t.fotoLingkungan.isNotEmpty&&File(t.fotoLingkungan).existsSync()){data['fotoLingkunganBase64']=base64Encode(await File(t.fotoLingkungan).readAsBytes());}final res=await ApiService.syncTemuan(token,data);if(res['success']==true){await d.update('temuan_inspeksi',{'is_dirty':0,'link_foto':'${res['linkFoto']??''}','link_lingkungan':'${res['linkLingkungan']??''}','folder_path':'${res['folderPath']??t.folderPath}'},where:'kode_temuan=?',whereArgs:[t.kodeTemuan]);}}
  }
  Future<List<Map<String,dynamic>>> master(String dataset) async {final d=await _db.database;final rows=await d.query('master_data_rows',columns:['payload_json'],where:'dataset=?',whereArgs:[dataset]);return rows.map((r)=>Map<String,dynamic>.from(jsonDecode('${r['payload_json']}'))).toList();}
  String jenisObject(Map<String,dynamic> sesi){final s='${sesi['subTim']??sesi['tim']??''}'.toLowerCase();if(s.contains('inspeksi jaringan')||s.contains('insjar'))return 'Jaringan';if(s.contains('inspeksi gardu')||s.contains('insdu'))return 'Gardu';return '';}
  String prioritas(String temuan,double? jarak,double? tinggi,List<Map<String,dynamic>> master){final veg={'Rabas / Pangkas','Tebang Sedang','Tebang Besar'}.contains(temuan);if(veg){final j=jarak??0,h=tinggi??0;if(h<9)return j>5?'Minor':'Mayor';if(j<3)return 'Mayor';if(j<6)return 'Sedang';return 'Minor';}for(final r in master){if('${r['Temuan']??''}'.trim()==temuan)return '${r['Prioritas']??''}';}return '';}
  static String folder(WoInsjar wo,String object,String kode,DateTime now){const b=['Januari','Februari','Maret','April','Mei','Juni','Juli','Agustus','September','Oktober','November','Desember'];return 'SiManDist/Rekap Temuan Inspeksi/${wo.kodeUlp}/$object/${now.year}/${now.month.toString().padLeft(2,'0')}. ${b[now.month-1]}/${now.day.toString().padLeft(2,'0')}/${wo.kodeWo}/$kode/';}
}