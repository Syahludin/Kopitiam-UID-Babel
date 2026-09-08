import 'package:flutter/material.dart';
import '../models/har_execution.dart';
import '../services/har_execution_repository.dart';

class HarJobFormScreen extends StatefulWidget {
  final HarExecution item;
  final HarExecutionRepository repository;
  const HarJobFormScreen({super.key,required this.item,required this.repository});
  @override
  State<HarJobFormScreen> createState()=>_HarJobFormScreenState();
}
class _MaterialInput {
  String? code,ownership;
  final quantity=TextEditingController();
  void dispose()=>quantity.dispose();
}
class _HarJobFormScreenState extends State<HarJobFormScreen> with SingleTickerProviderStateMixin {
  late final TabController tabs;
  final description=TextEditingController(),quantity=TextEditingController(),set=TextEditingController();
  final rows=<_MaterialInput>[];
  List<HarMaterial> master=[];
  bool loading=true,saving=false;
  String? error;
  @override
  void initState(){super.initState();tabs=TabController(length:2,vsync:this)..addListener(_changed);_load();}
  void _changed(){if(mounted)setState((){});}
  Future<void> _load()async{try{master=await widget.repository.materialMaster();}catch(e){error='$e';}finally{if(mounted)setState(()=>loading=false);}}
  @override
  void dispose(){tabs.dispose();description.dispose();quantity.dispose();set.dispose();for(final row in rows){row.dispose();}super.dispose();}
  Future<void> _save()async{
    if(saving)return;
    setState((){saving=true;error=null;});
    try{
      await widget.repository.addJob(widget.item.type,widget.item.code,description:description.text,quantity:double.tryParse(quantity.text.replaceAll(',','.'))??double.nan,set:set.text,materials:rows.map((r)=>{'Kode Material':r.code,'Jumlah':double.tryParse(r.quantity.text.replaceAll(',','.'))??double.nan,'Kepemilikan':r.ownership}).toList());
      if(mounted)Navigator.pop(context,true);
    }catch(e){if(mounted)setState(()=>error=e.toString().replaceFirst('Bad state: ',''));}finally{if(mounted)setState(()=>saving=false);}
  }
  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Tambah pekerjaan'),bottom:TabBar(controller:tabs,labelColor:Theme.of(context).colorScheme.onPrimary,unselectedLabelColor:Theme.of(context).colorScheme.onPrimary,tabs:const [Tab(text:'Pekerjaan'),Tab(text:'Material')])),
    body:Column(children:[
      if(error!=null)Padding(padding:const EdgeInsets.all(16),child:Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
      Expanded(child:TabBarView(controller:tabs,children:[
        ListView(padding:const EdgeInsets.all(18),children:[Text(widget.item.code,style:Theme.of(context).textTheme.titleMedium),const SizedBox(height:4),Text('Temuan: ${widget.item.value('Kode Temuan')}'),const SizedBox(height:20),TextField(controller:description,enabled:!saving,maxLines:3,decoration:const InputDecoration(labelText:'Uraian Pekerjaan')),const SizedBox(height:16),TextField(controller:quantity,enabled:!saving,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Jumlah')),const SizedBox(height:16),TextField(controller:set,enabled:!saving,decoration:const InputDecoration(labelText:'Set')),const SizedBox(height:20),const Text('Identitas, aset, Jenis WO, dan Kode Temuan mengikuti WO. User Input dan Waktu Input otomatis.')]),
        ListView(padding:const EdgeInsets.fromLTRB(18,18,18,100),children:[
          Text('Material pekerjaan',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:8),const Text('Tambahkan hanya material yang digunakan pada pekerjaan ini.'),const SizedBox(height:16),
          if(loading)const LinearProgressIndicator(),
          if(!loading&&master.isEmpty)const Text('Master material belum tersedia. Kembali ke Beranda dan unduh master terlebih dahulu.'),
          if(rows.isEmpty&&!loading)const Padding(padding:EdgeInsets.symmetric(vertical:24),child:Text('Belum ada material. Pekerjaan tanpa material tetap dapat disimpan.')),
          for(int i=0;i<rows.length;i++)_material(i),
        ]),
      ])),
      SafeArea(top:false,child:Padding(padding:const EdgeInsets.all(16),child:SizedBox(width:double.infinity,child:FilledButton(onPressed:saving?null:_save,child:Text(saving?'Menyimpan...':'Simpan pekerjaan'))))),
    ]),
    floatingActionButton:tabs.index==1?Padding(padding:const EdgeInsets.only(bottom:80),child:FloatingActionButton(tooltip:'Tambah material',onPressed:loading||saving||master.isEmpty?null:()=>setState(()=>rows.add(_MaterialInput())),child:const Icon(Icons.add))):null,
  );
  Widget _material(int index){
    final row=rows[index];final matches=master.where((m)=>m.code==row.code).toList();final unit=matches.length==1?matches.single.unit:'';
    final codes=master.map((m)=>m.code).toSet().where((c)=>master.where((m)=>m.code==c).length==1);
    return Padding(key:ObjectKey(row),padding:const EdgeInsets.only(bottom:24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Expanded(child:Text('Material ${index+1}',style:Theme.of(context).textTheme.titleMedium)),IconButton(tooltip:'Hapus baris material',onPressed:saving?null:()=>setState((){rows.removeAt(index).dispose();}),icon:const Icon(Icons.close))]),
      DropdownButtonFormField<String>(initialValue:row.code,isExpanded:true,decoration:const InputDecoration(labelText:'Nama Material'),items:codes.map((c){final m=master.firstWhere((m)=>m.code==c);return DropdownMenuItem(value:c,child:Text('${m.name} (${m.code})',overflow:TextOverflow.ellipsis));}).toList(),onChanged:saving?null:(v)=>setState(()=>row.code=v)),
      const SizedBox(height:12),TextField(controller:row.quantity,enabled:!saving,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:unit.isEmpty?'Jumlah Material':'Jumlah Material ($unit)',helperText:unit.isEmpty?'Pilih material untuk melihat satuannya.':'Satuan otomatis: $unit')),
      const SizedBox(height:12),DropdownButtonFormField<String>(initialValue:row.ownership,isExpanded:true,decoration:const InputDecoration(labelText:'Kepemilikan'),items:HarMaterial.ownership.map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:saving?null:(v)=>setState(()=>row.ownership=v)),const SizedBox(height:12),const Divider(),
    ]));
  }
}
