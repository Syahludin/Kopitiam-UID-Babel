import 'package:flutter/material.dart';
import '../models/har_execution.dart';
import '../theme/kopitiam_theme.dart';

/// Uses the existing inspection card rhythm: status tint, 16px radius, 15px inset.
class HarExecutionCard extends StatelessWidget {
  final HarExecution item;
  final VoidCallback? onTap;
  const HarExecutionCard({super.key, required this.item, this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
    padding:const EdgeInsets.only(bottom:12),
    child:Material(
      color:item.finished ? KopitiamColors.successSoft : item.started ? KopitiamColors.cyanSoft : KopitiamColors.surface,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16),side:const BorderSide(color:KopitiamColors.line)),
      child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(16),child:Padding(padding:const EdgeInsets.all(15),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[Expanded(child:Text(item.code,style:const TextStyle(fontWeight:FontWeight.w800))),const SizedBox(width:8),Flexible(child:Text(item.status,style:TextStyle(fontSize:12,fontWeight:FontWeight.w700,color:item.finished?KopitiamColors.success:KopitiamColors.ocean)))]),
        const SizedBox(height:9),Text(item.type==HarExecution.du?item.value('Nomor Gardu'):item.value('Penyulang'),style:Theme.of(context).textTheme.titleMedium),
        const SizedBox(height:4),Text('${item.value('Section')} • ${item.type==HarExecution.jar?item.value('Segmen'):item.value('Penyulang')}',style:Theme.of(context).textTheme.bodySmall),
        const SizedBox(height:8),Text(item.value('Temuan'),maxLines:2,overflow:TextOverflow.ellipsis),
        const SizedBox(height:12),Wrap(spacing:12,runSpacing:8,children:[Text(item.value('Prioritas'),style:const TextStyle(fontWeight:FontWeight.w700)),Text(item.value('Pekerjaan (Padam / Tanpa Padam)'))]),
        const Divider(height:24),Row(children:[Icon(item.error.isNotEmpty?Icons.error_outline:item.dirty?Icons.cloud_upload_outlined:Icons.cloud_done_outlined,size:18,color:item.error.isNotEmpty?KopitiamColors.danger:KopitiamColors.ocean),const SizedBox(width:6),Expanded(child:Text(item.error.isNotEmpty?'Gagal sinkron':item.dirty?'Belum sinkron':'Tersimpan',style:Theme.of(context).textTheme.bodySmall)),Text(item.finished?'Lihat':item.started?'Buka detail':'Mulai pekerjaan',style:const TextStyle(fontWeight:FontWeight.w800,color:KopitiamColors.ocean)),const Icon(Icons.chevron_right,color:KopitiamColors.ocean)]),
      ]))),
    ),
  );
}
