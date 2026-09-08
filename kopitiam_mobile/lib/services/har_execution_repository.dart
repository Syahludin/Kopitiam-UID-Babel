import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/har_execution.dart';
import '../models/temuan_inspeksi.dart';
import '../models/wo_insjar.dart';
import 'api_service.dart';
import 'photo_watermark_service.dart';
import 'sqlite_service.dart';

typedef HarDownload = Future<Map<String, dynamic>> Function(String type, String token);
typedef HarSend = Future<Map<String, dynamic>> Function(String type, String token, List<Map<String, dynamic>> rows);

class HarExecutionRepository {
  final Map<String, dynamic> session;
  final Database? database;
  final HarDownload downloadApi;
  final HarSend sendApi;
  Future<Database>? _ready;
  bool _busy = false;
  HarExecutionRepository(this.session, {this.database, HarDownload? downloadApi, HarSend? sendApi}) : downloadApi = downloadApi ?? _download, sendApi = sendApi ?? _send;
  static Future<Map<String, dynamic>> _download(String type, String token) => type == HarExecution.jar ? ApiService.getWoHarJar(token) : ApiService.getWoHarDu(token);
  static Future<Map<String, dynamic>> _send(String type, String token, List<Map<String, dynamic>> rows) => type == HarExecution.jar ? ApiService.syncWoHarJar(token, rows) : ApiService.syncWoHarDu(token, rows);
  String get owner => '${session['username'] ?? ''}'.trim().toLowerCase();
  String get token => '${session['token'] ?? ''}';
  void _access(String type) {
    if (owner.isEmpty || !HarExecution.allowedTypes(session).contains(type)) throw StateError('Akun tidak memiliki akses WO ini.');
  }
  Future<Database> _db() => _ready ??= _init();
  Future<Database> _init() async {
    final db = database ?? await SqliteService.instance.database;
    await db.execute('''CREATE TABLE IF NOT EXISTS har_execution_v2 (
      owner TEXT NOT NULL, jenis_wo TEXT NOT NULL, kode_wo TEXT NOT NULL,
      payload TEXT NOT NULL, PRIMARY KEY(owner,jenis_wo,kode_wo))''');
    return db;
  }
  Future<void> _put(DatabaseExecutor db, HarExecution item) => db.insert('har_execution_v2', {'owner': owner, 'jenis_wo': item.type, 'kode_wo': item.code, 'payload': jsonEncode(item.toJson())}, conflictAlgorithm: ConflictAlgorithm.replace).then((_) {});
  Future<HarExecution?> _get(DatabaseExecutor db, String type, String code) async {
    final rows = await db.query('har_execution_v2', where: 'owner = ? AND jenis_wo = ? AND kode_wo = ?', whereArgs: [owner,type,code]);
    return rows.isEmpty ? null : HarExecution.decode('${rows.first['payload']}');
  }
  Future<HarExecution?> get(String type, String code) async { _access(type); return _get(await _db(), type, code); }
  Future<List<HarExecution>> list(String type) async {
    _access(type);
    final rows = await (await _db()).query('har_execution_v2', where: 'owner = ? AND jenis_wo = ?', whereArgs: [owner,type], orderBy: 'kode_wo DESC');
    return rows.map((e) => HarExecution.decode('${e['payload']}')).toList();
  }
  Future<int> download(String type) async {
    _access(type);
    final response = await downloadApi(type, token);
    if (response['success'] != true || response['rows'] is! List) throw StateError('${response['message'] ?? 'Download gagal.'}');
    final db = await _db();
    int count = 0;
    await db.transaction((txn) async {
      for (final raw in response['rows'] as List) {
        final row = Map<String, dynamic>.from(raw as Map)..['Jenis WO'] = type;
        final code = '${row['Kode WO'] ?? ''}'.trim();
        if (code.isEmpty) continue;
        final old = await _get(txn, type, code);
        // Never overwrite unfinished local edits or a pending upload.
        if (old != null && (old.dirty || old.started)) continue;
        final item = HarExecution(header: row);
        if (old == null && item.finished) continue;
        await _put(txn, item);
        count++;
      }
    });
    return count;
  }
  Future<void> start(String type, String code) async {
    _access(type); final db = await _db();
    await db.transaction((txn) async {
      final item = await _get(txn,type,code);
      if (item == null) throw StateError('WO belum diunduh.');
      if (item.started) return;
      await _put(txn,item.change(header: {...item.header, 'Status WO': HarExecution.progress, 'Waktu Mulai': WoInsjar.stampLengkap(DateTime.now())}, dirty:true, revision:item.revision+1));
    });
  }
  Future<List<HarMaterial>> materialMaster() async {
    final db = await _db();
    final rows = await db.query('master_data_rows', columns:['payload_json'], where:'dataset = ?', whereArgs:['Master_Material']);
    final values = rows.map((r) => HarMaterial.fromMap(Map<String,dynamic>.from(jsonDecode('${r['payload_json']}')))).where((m)=>m.available).toList();
    values.sort((a,b)=>a.name.compareTo(b.name)); return values;
  }
  Future<void> downloadMaster() async {
    final response = await ApiService.getMasterData(token);
    if (response['success'] != true || response['datasets'] is! Map) throw StateError('${response['message'] ?? 'Master gagal diunduh.'}');
    await SqliteService.instance.replaceMasterData(Map<String,dynamic>.from(response['datasets']));
  }
  Future<void> addJob(String type,String code,{required String description, required double quantity, required String set, required List<Map<String,dynamic>> materials}) async {
    _access(type);
    if (description.trim().isEmpty || !quantity.isFinite || quantity<=0 || set.trim().isEmpty) throw StateError('Lengkapi Uraian Pekerjaan, Jumlah, dan Set.');
    final master = await materialMaster();
    final validated = <Map<String,dynamic>>[];
    for (final input in materials) {
      final matches = master.where((m)=>m.code == input['Kode Material']).toList();
      final qty = input['Jumlah'];
      if (matches.length != 1 || qty is! num || !qty.isFinite || qty<=0 || !HarMaterial.ownership.contains(input['Kepemilikan'])) throw StateError('Material, jumlah, satuan master, atau kepemilikan tidak valid.');
      validated.add({'Kode Penggunaan Material':HarExecution.newId('MAT'), 'Material':matches.single.name, 'Jumlah':qty, 'Satuan':matches.single.unit, 'Kepemilikan':input['Kepemilikan'], 'Catatan':''});
    }
    final db = await _db();
    await db.transaction((txn) async {
      final item = await _get(txn,type,code);
      if (item == null || !item.started || item.finished) throw StateError('WO harus dalam Progress Pekerjaan.');
      final stamp = WoInsjar.stampLengkap(DateTime.now());
      final id = HarExecution.newId('PKJ');
      final row = {...item.lineage(),'Kode Pekerjaan':id,'Uraian Pekerjaan':description.trim(),'Jumlah':quantity,'Set':set.trim(),'User Input':owner,'Waktu Input':stamp};
      final children = validated.map((m)=>{...item.lineage(),'Kode Pekerjaan':id,'Uraian Pekerjaan':description.trim(),'User Input':owner,'Waktu Input':stamp,...m}).toList();
      await _put(txn,item.change(jobs:[...item.jobs,row],materials:[...item.materials,...children],dirty:true,revision:item.revision+1));
    });
  }
  Future<void> finish(String type,String code,String photo,String notes) async {
    _access(type);
    final item = await get(type,code);
    if (item == null || !item.started || item.finished) throw StateError('WO tidak dapat diselesaikan.');
    final source = File(photo);
    if (!await source.exists() || await source.length()>5*1024*1024) throw StateError('Foto Sesudah wajib, maksimal 5 MB.');
    final image = img.decodeJpg(await source.readAsBytes());
    if (image == null || image.width<=image.height) throw StateError('Foto harus JPEG landscape dari kamera.');
    final stamp = WoInsjar.stampLengkap(DateTime.now());
    final watermark = TemuanInspeksi(kodeTemuan:item.value('Kode Temuan'),kodeWo:item.code,jenisObject:item.value('Jenis Object'),temuan:item.value('Temuan'),ulp:item.value('ULP'),penyulang:item.value('Penyulang'),section:item.value('Section'),segmen:item.value('Segmen'),nomorGardu:item.value('Nomor Gardu'),koordinat:item.value('Koordinat'),waktuInput:stamp,userInput:owner);
    final rendered = await PhotoWatermarkService.render(sourcePath:photo,item:watermark,photoLabel:'Foto Sesudah');
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path,'har_execution_photos',owner.replaceAll(RegExp(r'[^A-Za-z0-9._-]'),'_')));
    await dir.create(recursive:true);
    final target = await File(rendered).copy(p.join(dir.path,'${HarExecution.newId('HAR')}.jpg'));
    final db = await _db();
    await db.transaction((txn) async {
      final current = await _get(txn,type,code);
      if (current == null || current.finished) throw StateError('WO sudah selesai.');
      await _put(txn,current.change(header:{...current.header,'Status WO':HarExecution.done,'Waktu Selesai':stamp,'User Input':owner,'Catatan Petugas':notes.trim()},photo:target.path,dirty:true,revision:current.revision+1));
    });
  }
  Future<String> sync(String type) async {
    _access(type);
    if (_busy) return 'Sinkronisasi masih berjalan.';
    _busy=true;
    int ok=0,failed=0;
    try {
      for (final item in (await list(type)).where((e)=>e.dirty)) {
        try {
          final payload = {'schemaVersion':2, ...item.header,'jobs':item.jobs,'materials':item.materials};
          if (item.finished) {
            final photo = File(item.photo);
            if (!await photo.exists()) throw StateError('Foto lokal tidak ditemukan; data tetap disimpan.');
            payload['fotoSesudahBase64'] = base64Encode(await photo.readAsBytes());
          }
          final response = await sendApi(type,token,[payload]);
          final accepted = response['accepted'] as List? ?? [];
          if (response['success'] != true || !accepted.contains(item.code)) throw StateError('${response['message'] ?? 'Konfirmasi server tidak lengkap.'}');
          final db = await _db();
          await db.transaction((txn) async {
            final current = await _get(txn,type,item.code);
            if (current == null || current.revision != item.revision) return;
            final links = response['photos'] as Map? ?? {};
            await _put(txn,current.change(dirty:false,error:'',header:{...current.header,if(links[item.code] is Map) ...Map<String,dynamic>.from(links[item.code] as Map)}));
          }); ok++;
        } catch(e) {
          final db=await _db();
          await db.transaction((txn) async {final current=await _get(txn,type,item.code);if(current!=null)await _put(txn,current.change(error:'$e'));});failed++;
        }
      }
    } finally {_busy=false;}
    return '$ok WO tersinkron, $failed gagal. Data lokal dipertahankan.';
  }
}
