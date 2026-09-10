import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/wo_insdu.dart';
import '../models/wo_insjar.dart';
import '../services/wo_insdu_repository.dart';
import 'temuan_tab.dart';

class WoInsduFormScreen extends StatefulWidget {
  final WoInsdu existing;
  final Map<String, dynamic> sesi;
  const WoInsduFormScreen({super.key, required this.existing, required this.sesi});
  @override
  State<WoInsduFormScreen> createState() => _WoInsduFormScreenState();
}

class _WoInsduFormScreenState extends State<WoInsduFormScreen> with SingleTickerProviderStateMixin {
  static const blue = Color(0xFF004D8C), navy = Color(0xFF071B30), amber = Color(0xFFFFB800), muted = Color(0xFF64748B), line = Color(0xFFE2E8F0);
  static const coverOptions = ['Lengkap', 'Tidak Lengkap', 'Rusak', 'Tidak ada'];
  static const jumperOptions = ['A3C', 'A3CS (Lengkap)', 'A3CS (Tidak Lengkap)', 'Protective Sleeve (Lengkap)', 'Protective Sleeve (Tidak Lengkap)'];
  static const numericLabels = <String, String>{
    'bebanUtamaRWbp':'Beban Utama R (A) WBP','bebanUtamaSWbp':'Beban Utama S (A) WBP','bebanUtamaTWbp':'Beban Utama T (A) WBP','bebanJurusanNWbp':'Beban Jurusan N (A) WBP',
    'teganganRswbp':'Tegangan R-S (V) WBP','teganganStwbp':'Tegangan S-T (V) WBP','teganganRtwbp':'Tegangan R-T (V) WBP','teganganRnwbp':'Tegangan R-N (V) WBP','teganganSnwbp':'Tegangan S-N (V) WBP','teganganTnwbp':'Tegangan T-N (V) WBP',
    'bebanUtamaRLwbp':'Beban Utama R (A) LWBP','bebanUtamaSLwbp':'Beban Utama S (A) LWBP','bebanUtamaTLwbp':'Beban Utama T (A) LWBP','bebanJurusanNLwbp':'Beban Jurusan N (A) LWBP',
    'teganganRslwbp':'Tegangan R-S (V) LWBP','teganganStlwbp':'Tegangan S-T (V) LWBP','teganganRtlwbp':'Tegangan R-T (V) LWBP','teganganRnlwbp':'Tegangan R-N (V) LWBP','teganganSnlwbp':'Tegangan S-N (V) LWBP','teganganTnlwbp':'Tegangan T-N (V) LWBP',
  };
  static const conditionLabels = <String, String>{
    'coverFcoAtas':'Cover FCO Atas','coverFcoBawah':'Cover FCO Bawah','coverBushingTm':'Cover Bushing TM','coverBushingTr':'Cover Bushing TR','coverArrester':'Cover Arrester','jumperanAtas':'Jumperan Atas','jumperanBawah':'Jumperan Bawah',
  };

  final _repo = WoInsduRepository();
  final Map<String, TextEditingController> _fields = {};
  late final TabController _tabs;
  bool _saving = false, _finish = false;
  WoInsdu get wo => widget.existing;
  bool get readOnly => WoInsdu.normalisasiStatus(wo.statusWo) == WoInsdu.statusSelesai;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    final values = <String,Object?>{
      'bebanUtamaRWbp':wo.bebanUtamaRWbp,'bebanUtamaSWbp':wo.bebanUtamaSWbp,'bebanUtamaTWbp':wo.bebanUtamaTWbp,'bebanJurusanNWbp':wo.bebanJurusanNWbp,
      'teganganRswbp':wo.teganganRswbp,'teganganStwbp':wo.teganganStwbp,'teganganRtwbp':wo.teganganRtwbp,'teganganRnwbp':wo.teganganRnwbp,'teganganSnwbp':wo.teganganSnwbp,'teganganTnwbp':wo.teganganTnwbp,
      'bebanUtamaRLwbp':wo.bebanUtamaRLwbp,'bebanUtamaSLwbp':wo.bebanUtamaSLwbp,'bebanUtamaTLwbp':wo.bebanUtamaTLwbp,'bebanJurusanNLwbp':wo.bebanJurusanNLwbp,
      'teganganRslwbp':wo.teganganRslwbp,'teganganStlwbp':wo.teganganStlwbp,'teganganRtlwbp':wo.teganganRtlwbp,'teganganRnlwbp':wo.teganganRnlwbp,'teganganSnlwbp':wo.teganganSnlwbp,'teganganTnlwbp':wo.teganganTnlwbp,
      'coverFcoAtas':wo.coverFcoAtas,'coverFcoBawah':wo.coverFcoBawah,'coverBushingTm':wo.coverBushingTm,'coverBushingTr':wo.coverBushingTr,'coverArrester':wo.coverArrester,'jumperanAtas':wo.jumperanAtas,'jumperanBawah':wo.jumperanBawah,
    };
    for (final entry in values.entries) {
      final raw = entry.value == null ? '' : '${entry.value}';
      _fields[entry.key] = TextEditingController(text: numericLabels.containsKey(entry.key) ? raw.replaceAll('.', ',') : raw);
    }
  }
  @override
  void dispose() { _tabs.dispose(); for (final value in _fields.values) { value.dispose(); } super.dispose(); }

  String? _decimalError(String key) {
    final value = _fields[key]!.text.trim();
    if (value.isEmpty) return null;
    if (value.contains('.')) return 'Gunakan (,) sebagai pemisah';
    return RegExp(r'^\d+(,\d+)?$').hasMatch(value) ? null : 'Masukkan angka yang valid';
  }
  bool get _hasDecimalError => numericLabels.keys.any((key) => _decimalError(key) != null);
  double? _number(String key) { final value = _fields[key]!.text.trim().replaceAll(',', '.'); return value.isEmpty ? null : double.tryParse(value); }
  String _text(String key) => _fields[key]!.text.trim();
  String get _coordinate => wo.koordinatGardu.trim().isNotEmpty ? wo.koordinatGardu.trim() : wo.lat.trim().isNotEmpty && wo.long.trim().isNotEmpty ? '${wo.lat.trim()}, ${wo.long.trim()}' : '';

  Future<void> _openMaps() async {
    if (_coordinate.isEmpty) { _message('Koordinat Gardu belum tersedia.'); return; }
    await launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(_coordinate)}'), mode: LaunchMode.externalApplication);
  }
  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _save() async {
    if (_saving || readOnly) return;
    if (_hasDecimalError) { setState(() {}); _message('Perbaiki kolom merah. Gunakan (,) sebagai pemisah.'); return; }
    setState(() => _saving = true);
    try {
      final now = DateTime.now(), start = WoInsjar.parseStamp(wo.waktuMulai) ?? DateTime.now();
      final saved = WoInsdu(
        id:wo.id,no:wo.no,kodeWo:wo.kodeWo,kodeUiw:wo.kodeUiw,kodeUp3:wo.kodeUp3,kodeUlp:wo.kodeUlp,ulp:wo.ulp,hari:wo.hari,tanggal:wo.tanggal,penyulang:wo.penyulang,section:wo.section,nomorGardu:wo.nomorGardu,koordinatGardu:wo.koordinatGardu,lat:wo.lat,long:wo.long,jurusan:wo.jurusan,
        bebanUtamaRWbp:_number('bebanUtamaRWbp'),bebanUtamaSWbp:_number('bebanUtamaSWbp'),bebanUtamaTWbp:_number('bebanUtamaTWbp'),bebanJurusanNWbp:_number('bebanJurusanNWbp'),
        teganganRswbp:_number('teganganRswbp'),teganganStwbp:_number('teganganStwbp'),teganganRtwbp:_number('teganganRtwbp'),teganganRnwbp:_number('teganganRnwbp'),teganganSnwbp:_number('teganganSnwbp'),teganganTnwbp:_number('teganganTnwbp'),
        bebanUtamaRLwbp:_number('bebanUtamaRLwbp'),bebanUtamaSLwbp:_number('bebanUtamaSLwbp'),bebanUtamaTLwbp:_number('bebanUtamaTLwbp'),bebanJurusanNLwbp:_number('bebanJurusanNLwbp'),
        teganganRslwbp:_number('teganganRslwbp'),teganganStlwbp:_number('teganganStlwbp'),teganganRtlwbp:_number('teganganRtlwbp'),teganganRnlwbp:_number('teganganRnlwbp'),teganganSnlwbp:_number('teganganSnlwbp'),teganganTnlwbp:_number('teganganTnlwbp'),
        coverFcoAtas:_text('coverFcoAtas'),coverFcoBawah:_text('coverFcoBawah'),coverBushingTm:_text('coverBushingTm'),coverBushingTr:_text('coverBushingTr'),coverArrester:_text('coverArrester'),jumperanAtas:_text('jumperanAtas'),jumperanBawah:_text('jumperanBawah'),
        waktuMulai:wo.waktuMulai.isEmpty ? WoInsjar.stampLengkap(start) : wo.waktuMulai,waktuSelesai:_finish ? WoInsjar.stampLengkap(now) : wo.waktuSelesai,durasiPekerjaan:_finish ? WoInsjar.hitungDurasi(start, now) : wo.durasiPekerjaan,statusWo:_finish ? WoInsdu.statusSelesai : WoInsdu.statusDalam,isDirty:_finish,
      );
      await _repo.simpan(saved, dirty: _finish);
      if (mounted) Navigator.pop(context, true);
    } finally { if (mounted) setState(() => _saving = false); }
  }

  WoInsjar get _findingWo => WoInsjar(kodeWo:wo.kodeWo,kodeUiw:wo.kodeUiw,kodeUp3:wo.kodeUp3,kodeUlp:wo.kodeUlp,ulp:wo.ulp,hari:wo.hari,tanggal:wo.tanggal,penyulang:wo.penyulang,section:wo.section,statusWo:WoInsjar.statusDalam);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF4F7FB),
    appBar: AppBar(backgroundColor:blue,foregroundColor:Colors.white,title:const Text('WO Inspeksi Gardu',style:TextStyle(fontWeight:FontWeight.w800)),bottom:TabBar(controller:_tabs,labelColor:Colors.white,unselectedLabelColor:Colors.white70,indicatorColor:const Color(0xFF00E5FF),tabs:const [Tab(text:'Detail'),Tab(text:'Pengukuran'),Tab(text:'Temuan')])),
    body: TabBarView(controller:_tabs,children:[_detailTab(),_measurementTab(),TemuanTab(wo:_findingWo,sesi:widget.sesi,canAddTemuan:!readOnly)]),
  );

  Widget _detailTab() => ListView(padding:const EdgeInsets.all(16),children:[
    _card('Identitas Work Order',[_row('Kode WO',wo.kodeWo),_row('ULP',wo.ulp),_row('Tanggal','${wo.hari}, ${wo.tanggal}'),_row('Penyulang',wo.penyulang),_row('Section',wo.section),_row('Nomor Gardu',wo.nomorGardu),_row('Jurusan',wo.jurusan),const SizedBox(height:12),
      InkWell(onTap:_openMaps,borderRadius:BorderRadius.circular(12),child:Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:const Color(0xFFE8F1FA),borderRadius:BorderRadius.circular(12),border:Border.all(color:const Color(0xFFB8DCEF))),child:Row(children:[const Icon(Icons.directions_rounded,color:blue),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Koordinat Gardu',style:TextStyle(color:blue,fontWeight:FontWeight.w800)),Text(_coordinate.isEmpty?'Belum tersedia':_coordinate,style:const TextStyle(color:muted,fontSize:12))])),const Icon(Icons.open_in_new_rounded,color:blue,size:18)])))
    ]),const SizedBox(height:14),_card('Status Pekerjaan',[_row('Status WO',WoInsdu.normalisasiStatus(wo.statusWo)),_row('Waktu Mulai',wo.waktuMulai),_row('Waktu Selesai',wo.waktuSelesai),_row('Durasi',wo.durasiPekerjaan)])
  ]);

  Widget _measurementTab() => Column(children:[Expanded(child:ListView(padding:const EdgeInsets.all(16),children:[_inputGroup('Pengukuran WBP',numericLabels.entries.take(10)),const SizedBox(height:14),_inputGroup('Pengukuran LWBP',numericLabels.entries.skip(10)),const SizedBox(height:14),_conditionGroup()])),if(!readOnly)Container(color:Colors.white,padding:EdgeInsets.fromLTRB(16,12,16,12+MediaQuery.paddingOf(context).bottom),child:Row(children:[Expanded(child:OutlinedButton(onPressed:_saving?null:(){_finish=false;_save();},child:const Text('Simpan Draft'))),const SizedBox(width:10),Expanded(child:ElevatedButton(onPressed:_saving?null:(){_finish=true;_save();},style:ElevatedButton.styleFrom(backgroundColor:amber,foregroundColor:navy),child:Text(_saving?'Menyimpan...':'Selesaikan WO')))]))]);

  Widget _inputGroup(String title, Iterable<MapEntry<String,String>> entries) => _card(title,entries.map((entry)=>Padding(padding:const EdgeInsets.only(bottom:12),child:TextField(controller:_fields[entry.key],enabled:!readOnly,keyboardType:const TextInputType.numberWithOptions(decimal:true),onChanged:(_)=>setState((){}),decoration:InputDecoration(labelText:entry.value,errorText:_decimalError(entry.key),errorStyle:const TextStyle(color:Colors.red,fontWeight:FontWeight.w700),border:OutlineInputBorder(borderRadius:BorderRadius.circular(12)),errorBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:const BorderSide(color:Colors.red,width:1.5)),focusedErrorBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:const BorderSide(color:Colors.red,width:2)))))).toList());

  Widget _conditionGroup() => _card('Kondisi Cover & Jumperan',conditionLabels.entries.map((entry){
    final options = entry.key.startsWith('jumperan') ? jumperOptions : coverOptions;
    final current = _text(entry.key);
    return Padding(padding:const EdgeInsets.only(bottom:12),child:DropdownButtonFormField<String>(key:ValueKey('condition-${entry.key}-$current'),isExpanded:true,initialValue:options.contains(current)?current:null,hint:const Text('Pilih kondisi'),items:options.map((value)=>DropdownMenuItem(value:value,child:Text(value))).toList(),onChanged:readOnly?null:(value)=>setState(()=>_fields[entry.key]!.text=value??''),decoration:InputDecoration(labelText:entry.value,border:OutlineInputBorder(borderRadius:BorderRadius.circular(12)))));
  }).toList());

  Widget _card(String title,List<Widget> children)=>Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),border:Border.all(color:line)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(color:blue,fontSize:16,fontWeight:FontWeight.w800)),const SizedBox(height:14),...children]));
  Widget _row(String label,String value)=>Padding(padding:const EdgeInsets.only(bottom:10),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[SizedBox(width:112,child:Text(label,style:const TextStyle(color:muted))),Expanded(child:Text(value.trim().isEmpty?'-':value,textAlign:TextAlign.right,style:const TextStyle(color:navy,fontWeight:FontWeight.w700)))]));
}
