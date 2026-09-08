import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/har_execution.dart';
import '../services/har_execution_repository.dart';
import '../widgets/har_execution_card.dart';
import 'har_job_form_screen.dart';
import 'landscape_camera_screen.dart';
import 'settings_session_section.dart';
import 'widgets/bubble_navbar.dart';
import 'widgets/welcome_card.dart';

class HarExecutionScreen extends StatefulWidget {
  final Map<String,dynamic> sesi;
  final HarExecutionRepository? repository;
  const HarExecutionScreen({super.key,required this.sesi,this.repository});
  @override
  State<HarExecutionScreen> createState()=>_HarExecutionScreenState();
}
class _HarExecutionScreenState extends State<HarExecutionScreen>{
  late final HarExecutionRepository repo;
  late final List<String> types;
  late String type;
  int selected=1;
  bool busy=false;
  String? loadError;
  List<HarExecution> items=[];
  @override
  void initState(){super.initState();repo=widget.repository??HarExecutionRepository(widget.sesi);types=HarExecution.allowedTypes(widget.sesi);type=types.isEmpty?'':types.first;_load();}
  Future<void> _load()async{
    if(type.isEmpty)return;
    final requested=type;
    try{final data=await repo.list(requested);if(mounted&&type==requested)setState((){items=data;loadError=null;});}
    catch(e){if(mounted)setState(()=>loadError='$e');}
  }
  void _message(String text){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text)));}
  Future<void> _run(Future<String> Function() action)async{if(busy)return;setState(()=>busy=true);try{_message(await action());await _load();}catch(e){_message('$e');}finally{if(mounted)setState(()=>busy=false);}}
  Future<void> _tap(HarExecution item)async{
    if(busy)return;
    if(!item.started){
      final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Mulai pekerjaan?'),content:Text('Apakah Anda ingin mulai mengerjakan WO dengan kode: ${item.code}?'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Tidak')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Ya'))]));
      if(yes==true&&mounted)await _run(()async{await repo.start(item.type,item.code);return 'WO dimulai. Klik ulang card untuk membuka detail.';});
      return;
    }
    await Navigator.push<void>(context,MaterialPageRoute(builder:(_)=>HarWoDetailScreen(item:item,repository:repo)));
    await _load();
  }
  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(['Work Order Har','Beranda','Pengaturan'][selected])),
    body:types.isEmpty?const Center(child:Text('Tidak memiliki akses WO Har.')):Column(children:[
      if(types.length>1)Padding(padding:const EdgeInsets.all(16),child:SegmentedButton<String>(segments:types.map((t)=>ButtonSegment(value:t,label:Text(t))).toList(),selected:{type},onSelectionChanged:busy?null:(v){setState((){type=v.single;items=[];});_load();})),
      if(busy)const LinearProgressIndicator(),
      if(loadError!=null)Padding(padding:const EdgeInsets.all(16),child:Text(loadError!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
      Expanded(child:IndexedStack(index:selected,children:[
        RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(18),children:[if(items.isEmpty)const Padding(padding:EdgeInsets.symmetric(vertical:48),child:Text('Belum ada WO. Klik Download WO di Beranda.')), ...items.map((i)=>HarExecutionCard(item:i,onTap:busy?null:()=>_tap(i)))])),
        ListView(padding:const EdgeInsets.all(18),children:[WelcomeCard(sesi:widget.sesi),const SizedBox(height:24),Text(type,style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:12),Text('${items.length} WO • ${items.where((w)=>w.dirty).length} belum sinkron'),const SizedBox(height:20),ElevatedButton.icon(onPressed:busy?null:()=>_run(()async=>'${await repo.download(type)} WO diunduh. Buka menu WO untuk melihatnya.'),icon:const Icon(Icons.download),label:const Text('Download WO')),const SizedBox(height:12),FilledButton.icon(onPressed:busy?null:()=>_run(()=>repo.sync(type)),icon:const Icon(Icons.sync),label:const Text('Sinkron WO')),const SizedBox(height:12),OutlinedButton.icon(onPressed:busy?null:()=>_run(()async{await repo.downloadMaster();return 'Master material tersimpan.';}),icon:const Icon(Icons.inventory_2_outlined),label:const Text('Download master material'))]),
        ListView(padding:const EdgeInsets.all(18),children:[SettingsSessionSection(session:widget.sesi)]),
      ])),
    ]),
    bottomNavigationBar:BubbleNavbar(selectedIndex:selected,onTap:(i)=>setState(()=>selected=i)),
  );
}

class HarWoDetailScreen extends StatefulWidget{
  final HarExecution item;final HarExecutionRepository repository;
  const HarWoDetailScreen({super.key,required this.item,required this.repository});
  @override
  State<HarWoDetailScreen> createState()=>_HarWoDetailScreenState();
}
class _HarWoDetailScreenState extends State<HarWoDetailScreen> with SingleTickerProviderStateMixin{
  late HarExecution item;late final TabController tabs;final notes=TextEditingController();String photo='';bool busy=false;
  @override
  void initState(){super.initState();item=widget.item;photo=item.photo;notes.text=item.value('Catatan Petugas');tabs=TabController(length:2,vsync:this)..addListener(_changed);}
  void _changed(){if(mounted)setState((){});}
  @override
  void dispose(){tabs.dispose();notes.dispose();super.dispose();}
  Future<void> _reload()async{try{final next=await widget.repository.get(item.type,item.code);if(next!=null&&mounted)setState(()=>item=next);}catch(e){_message('$e');}}
  void _message(String text){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text)));}
  Future<void> _add()async{await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>HarJobFormScreen(item:item,repository:widget.repository)));await _reload();}
  Future<void> _photo()async{if(busy||item.finished)return;setState(()=>busy=true);try{final path=await LandscapeCameraScreen.capture(context,title:'Foto Sesudah');if(path!=null&&mounted)setState(()=>photo=path);}catch(e){_message('$e');}finally{if(mounted)setState(()=>busy=false);}}
  Future<void> _finish()async{if(busy||item.finished)return;setState(()=>busy=true);try{await widget.repository.finish(item.type,item.code,photo,notes.text);await _reload();_message('WO Selesai, tersimpan lokal. Sinkron dari Beranda.');}catch(e){_message('$e');}finally{if(mounted)setState(()=>busy=false);}}
  Future<void> _link(String url)async{final uri=Uri.tryParse(url);if(uri==null||uri.scheme!='https'){_message('Link belum tersedia.');return;}try{await launchUrl(uri,mode:LaunchMode.externalApplication);}catch(e){_message('$e');}}
  Widget _field(String label,dynamic value)=>Padding(
    padding:const EdgeInsets.only(bottom:12),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(label,style:Theme.of(context).textTheme.bodySmall),
      SelectableText('${value??''}'),
    ]),
  );
  Widget _job(Map<String,dynamic> job){
    final materials=item.materials.where((m)=>m['Kode Pekerjaan']==job['Kode Pekerjaan']).toList();
    return Padding(padding:const EdgeInsets.only(bottom:20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('${job['Uraian Pekerjaan']}',style:Theme.of(context).textTheme.titleMedium),const SizedBox(height:6),
      Text('${job['Jumlah']} ${job['Set']}'),Text('${job['Kode Pekerjaan']}',style:Theme.of(context).textTheme.bodySmall),
      ...materials.map((m)=>ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.inventory_2_outlined),title:Text('${m['Material']}'),subtitle:Text('${m['Kepemilikan']}'),trailing:Text('${m['Jumlah']} ${m['Satuan']}'))),
      if(materials.isEmpty)const Text('Tanpa material'),const Divider(),
    ]));
  }
  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Tindak lanjut WO'),bottom:TabBar(controller:tabs,labelColor:Theme.of(context).colorScheme.onPrimary,unselectedLabelColor:Theme.of(context).colorScheme.onPrimary,tabs:const [Tab(text:'Detail WO'),Tab(text:'Pekerjaan')])),
    body:TabBarView(controller:tabs,children:[
      ListView(padding:const EdgeInsets.all(18),children:[
        Text(item.code,style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:8),Text(item.status),const SizedBox(height:20),
        ...item.header.entries.where((e)=>!['Foto Sesudah','Link Foto Sesudah','Catatan Petugas','Status WO'].contains(e.key)).map((e)=>_field(e.key,e.value)),
        for(final key in ['Link Foto Temuan','Link Foto Tiang Sekitar'])if(item.value(key).isNotEmpty)OutlinedButton.icon(onPressed:()=>_link(item.value(key)),icon:const Icon(Icons.image_outlined),label:Text('Buka $key')),
        const Divider(height:32),Text('Foto Sesudah',style:Theme.of(context).textTheme.titleMedium),const SizedBox(height:12),
        if(photo.isNotEmpty&&File(photo).existsSync())ClipRRect(borderRadius:BorderRadius.circular(16),child:Image.file(File(photo),height:200,fit:BoxFit.cover)),
        if(!item.finished)OutlinedButton.icon(onPressed:busy?null:_photo,icon:const Icon(Icons.camera_alt_outlined),label:Text(photo.isEmpty?'Ambil foto':'Ambil ulang foto')),
        if(item.value('Link Foto Sesudah').isNotEmpty)TextButton(onPressed:()=>_link(item.value('Link Foto Sesudah')),child:const Text('Buka foto tersinkron')),
        const SizedBox(height:16),TextField(controller:notes,enabled:!item.finished&&!busy,maxLines:3,decoration:const InputDecoration(labelText:'Catatan Petugas')),
        const SizedBox(height:20),FilledButton(onPressed:item.finished||busy?null:_finish,child:Text(busy?'Menyimpan...':item.finished?'WO Selesai':'Simpan Selesai')),const SizedBox(height:24),
      ]),
      ListView(padding:const EdgeInsets.fromLTRB(18,18,18,100),children:[
        Text('${item.jobs.length} pekerjaan',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:16),
        if(item.jobs.isEmpty)const Text('Belum ada pekerjaan. Tekan + untuk menambah uraian pekerjaan dan material.'),
        ...item.jobs.map(_job),
      ]),
    ]),
    floatingActionButton:tabs.index==1&&!item.finished?FloatingActionButton(tooltip:'Tambah pekerjaan',onPressed:busy?null:_add,child:const Icon(Icons.add)):null,
  );
}
