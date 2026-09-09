import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/har_execution.dart';
import '../services/har_execution_repository.dart';
import '../theme/kopitiam_theme.dart';
import '../widgets/har_execution_card.dart';
import 'har_job_form_screen.dart';
import 'landscape_camera_screen.dart';
import 'settings_session_section.dart';
import 'widgets/bubble_navbar.dart';
import 'widgets/welcome_card.dart';
import 'widgets/wo_data_card.dart';

class HarExecutionScreen extends StatefulWidget {
  final Map<String, dynamic> sesi;
  final HarExecutionRepository? repository;
  const HarExecutionScreen({super.key, required this.sesi, this.repository});
  @override
  State<HarExecutionScreen> createState() => _HarExecutionScreenState();
}

class _HarExecutionScreenState extends State<HarExecutionScreen> {
  late final HarExecutionRepository repo;
  int selected = 1;
  bool busy = false;
  String? loadError;
  List<HarExecution> items = [];
  HarMasterState master = const HarMasterState(false, null);
  double? masterProgress;
  String masterLabel = 'Menyiapkan Data Master';

  bool get admin => HarExecution.isAdmin(widget.sesi);
  int get ready => items.where((item) => item.ready).length;
  int get progress => items.where((item) => item.started && !item.finished).length;
  int get done => items.where((item) => item.finished).length;

  @override
  void initState() {
    super.initState();
    repo = widget.repository ?? HarExecutionRepository(widget.sesi);
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final values = await Future.wait([repo.listAll(), repo.masterState()]);
      if (!mounted) return;
      setState(() {
        items = values[0] as List<HarExecution>;
        master = values[1] as HarMasterState;
        loadError = null;
      });
    } catch (error) {
      if (mounted) setState(() => loadError = '$error');
    }
  }

  void _message(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _run(Future<String> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      _message(await action());
      await _refresh();
    } catch (error) {
      _message('$error');
      rethrow;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _downloadWo() async {
    await _run(() async {
      final result = await repo.downloadAssigned();
      return result.empty
          ? 'Tidak ada WO untuk username ${repo.owner}.'
          : '${result.downloaded} WO diunduh untuk ${repo.owner}.';
    });
  }

  Future<void> _syncWo() => _run(repo.syncAll);

  Future<void> _downloadMaster() async {
    if (busy) return;
    setState(() {
      busy = true;
      masterProgress = 0;
      masterLabel = 'Menyiapkan Data Master';
    });
    try {
      await repo.downloadAllMasters((value, label) {
        if (mounted) setState(() { masterProgress = value; masterLabel = label; });
      });
      await _refresh();
      _message('Master Data Sync.');
    } catch (error) {
      _message('$error');
    } finally {
      if (mounted) setState(() { busy = false; masterProgress = null; });
    }
  }

  Future<void> _tap(HarExecution item) async {
    if (busy) return;
    if (!item.started) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Mulai pekerjaan?'),
          content: Text('Apakah Anda ingin mulai mengerjakan WO dengan kode: ${item.code}?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Tidak')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Ya')),
          ],
        ),
      );
      if (yes == true && mounted) {
        await _run(() async {
          await repo.start(item.type, item.code);
          return 'WO dimulai. Klik ulang card untuk membuka detail.';
        });
      }
      return;
    }
    await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => HarWoDetailScreen(item: item, repository: repo)));
    await _refresh();
  }

  String get lastSync {
    final date = master.lastSync;
    if (date == null) return 'Belum pernah sinkron';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(['Work Order Har', 'Beranda', 'Pengaturan'][selected])),
        body: Column(children: [
          if (busy && masterProgress == null) const LinearProgressIndicator(),
          if (loadError != null) Padding(padding: const EdgeInsets.all(12), child: Text(loadError!, style: const TextStyle(color: KopitiamColors.danger))),
          Expanded(child: IndexedStack(index: selected, children: [_work(), _home(), _settings()])),
        ]),
        bottomNavigationBar: BubbleNavbar(selectedIndex: selected, onTap: (index) => setState(() => selected = index)),
      );

  Widget _work() => RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            if (items.isEmpty) _empty('Belum ada WO untuk ${repo.owner}.', 'Tarik layar untuk refresh atau gunakan Download WO di Beranda.'),
            ...items.map((item) => HarExecutionCard(item: item, onTap: busy ? null : () => _tap(item))),
          ],
        ),
      );

  Widget _home() => RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(padding: const EdgeInsets.all(18), children: [
          WelcomeCard(sesi: widget.sesi),
          if (!admin) ...[
            const SizedBox(height: 20),
            _summary(),
            const SizedBox(height: 20),
            WoDataCard(
              isRow: false,
              dirty: items.where((item) => item.dirty).length,
              onDownload: _downloadWo,
              onSync: _syncWo,
            ),
          ],
        ]),
      );

  Widget _summary() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF063B5C), Color(0xFF087797), Color(0xFFD6A93A)], stops: [0, .8, 1.3], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [BoxShadow(color: Color(0x26063B5C), blurRadius: 22, offset: Offset(0, 10))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Ringkasan Work Order', style: TextStyle(color: KopitiamColors.surface, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Row(children: [_metric('Total', '${items.length}'), _metric('Siap', '$ready'), _metric('Progress', '$progress'), _metric('Selesai', '$done')]),
        ]),
      );

  Widget _metric(String label, String value) => Expanded(
        child: Column(children: [
          Text(value, style: const TextStyle(color: KopitiamColors.surface, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFD7EBEF), fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _settings() => RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(padding: const EdgeInsets.all(18), children: [
          _masterCard(),
          SettingsSessionSection(session: widget.sesi, showMasterGardu: false),
        ]),
      );

  Widget _masterCard() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFF6D03F), Color(0xFFD6A93A), Color(0xFF087797)], stops: [0, .58, 1.25], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [BoxShadow(color: Color(0x1F063B5C), blurRadius: 20, offset: Offset(0, 9))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.cloud_done_rounded, color: KopitiamColors.navy),
            const SizedBox(width: 10),
            Expanded(child: Text(master.synced ? 'Master Data Sync' : 'Master Data belum sinkron', style: const TextStyle(color: KopitiamColors.ink, fontSize: 18, fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 8),
          Text('Terakhir sync: $lastSync', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          const Row(children: [Icon(Icons.layers_rounded, size: 18), SizedBox(width: 8), Text('Master Pendukung'), Spacer(), Icon(Icons.domain_rounded, size: 18), SizedBox(width: 8), Text('Master Gardu')]),
          if (masterProgress != null) ...[
            const SizedBox(height: 18),
            Text(masterLabel, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: masterProgress),
            const SizedBox(height: 5),
            Text('${((masterProgress ?? 0) * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : _downloadMaster,
              icon: const Icon(Icons.download_for_offline_rounded),
              label: Text(master.synced ? 'Sinkron ulang semua master' : 'Download semua master'),
            ),
          ),
        ]),
      );

  Widget _empty(String title, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 20),
        child: Column(children: [
          const Icon(Icons.assignment_outlined, size: 48, color: KopitiamColors.ocean),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ]),
      );
}

class HarWoDetailScreen extends StatefulWidget {
  final HarExecution item;
  final HarExecutionRepository repository;
  const HarWoDetailScreen({super.key, required this.item, required this.repository});
  @override
  State<HarWoDetailScreen> createState() => _HarWoDetailScreenState();
}

class _HarWoDetailScreenState extends State<HarWoDetailScreen> with SingleTickerProviderStateMixin {
  late HarExecution item;
  late final TabController tabs;
  final notes = TextEditingController();
  String photo = '';
  bool busy = false;
  @override
  void initState() { super.initState(); item = widget.item; photo = item.photo; notes.text = item.value('Catatan Petugas'); tabs = TabController(length: 2, vsync: this)..addListener(_changed); }
  void _changed() { if (mounted) setState(() {}); }
  @override
  void dispose() { tabs.dispose(); notes.dispose(); super.dispose(); }
  Future<void> _reload() async { try { final next = await widget.repository.get(item.type, item.code); if (next != null && mounted) setState(() => item = next); } catch (error) { _message('$error'); } }
  void _message(String text) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); }
  Future<void> _add() async { await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => HarJobFormScreen(item: item, repository: widget.repository))); await _reload(); }
  Future<void> _photo() async { if (busy || item.finished) return; setState(() => busy = true); try { final path = await LandscapeCameraScreen.capture(context, title: 'Foto Sesudah'); if (path != null && mounted) setState(() => photo = path); } catch (error) { _message('$error'); } finally { if (mounted) setState(() => busy = false); } }
  Future<void> _finish() async { if (busy || item.finished) return; setState(() => busy = true); try { await widget.repository.finish(item.type, item.code, photo, notes.text); await _reload(); _message('WO Selesai, tersimpan lokal. Sinkron dari Beranda.'); } catch (error) { _message('$error'); } finally { if (mounted) setState(() => busy = false); } }
  Future<void> _link(String url) async { final uri = Uri.tryParse(url); if (uri == null || uri.scheme != 'https') { _message('Link belum tersedia.'); return; } try { await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (error) { _message('$error'); } }
  Widget _field(String label, dynamic value) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: Theme.of(context).textTheme.bodySmall), SelectableText('${value ?? ''}')]));
  Widget _job(Map<String, dynamic> job) { final materials = item.materials.where((material) => material['Kode Pekerjaan'] == job['Kode Pekerjaan']).toList(); return Padding(padding: const EdgeInsets.only(bottom: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${job['Uraian Pekerjaan']}', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 6), Text('${job['Jumlah']} ${job['Set']}'), Text('${job['Kode Pekerjaan']}', style: Theme.of(context).textTheme.bodySmall), ...materials.map((material) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.inventory_2_outlined), title: Text('${material['Material']}'), subtitle: Text('${material['Kepemilikan']}'), trailing: Text('${material['Jumlah']} ${material['Satuan']}'))), if (materials.isEmpty) const Text('Tanpa material'), const Divider()])); }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Tindak lanjut WO'), bottom: TabBar(controller: tabs, labelColor: Theme.of(context).colorScheme.onPrimary, unselectedLabelColor: Theme.of(context).colorScheme.onPrimary, tabs: const [Tab(text: 'Detail WO'), Tab(text: 'Pekerjaan')])),
        body: TabBarView(controller: tabs, children: [
          RefreshIndicator(onRefresh: _reload, child: ListView(padding: const EdgeInsets.all(18), children: [Text(item.code, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 8), Text(item.status), const SizedBox(height: 20), ...item.header.entries.where((entry) => !['Foto Sesudah','Link Foto Sesudah','Catatan Petugas','Status WO'].contains(entry.key)).map((entry) => _field(entry.key, entry.value)), for (final key in ['Link Foto Temuan','Link Foto Tiang Sekitar']) if (item.value(key).isNotEmpty) OutlinedButton.icon(onPressed: () => _link(item.value(key)), icon: const Icon(Icons.image_outlined), label: Text('Buka $key')), const Divider(height: 32), Text('Foto Sesudah', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 12), if (photo.isNotEmpty && File(photo).existsSync()) ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(File(photo), height: 200, fit: BoxFit.cover)), if (!item.finished) OutlinedButton.icon(onPressed: busy ? null : _photo, icon: const Icon(Icons.camera_alt_outlined), label: Text(photo.isEmpty ? 'Ambil foto' : 'Ambil ulang foto')), if (item.value('Link Foto Sesudah').isNotEmpty) TextButton(onPressed: () => _link(item.value('Link Foto Sesudah')), child: const Text('Buka foto tersinkron')), const SizedBox(height: 16), TextField(controller: notes, enabled: !item.finished && !busy, maxLines: 3, decoration: const InputDecoration(labelText: 'Catatan Petugas')), const SizedBox(height: 20), FilledButton(onPressed: item.finished || busy ? null : _finish, child: Text(busy ? 'Menyimpan...' : item.finished ? 'WO Selesai' : 'Simpan Selesai')), const SizedBox(height: 24)])),
          RefreshIndicator(onRefresh: _reload, child: ListView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 100), children: [Text('${item.jobs.length} pekerjaan', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 16), if (item.jobs.isEmpty) const Text('Belum ada pekerjaan. Tekan + untuk menambah uraian pekerjaan dan material.'), ...item.jobs.map(_job)])),
        ]),
        floatingActionButton: tabs.index == 1 && !item.finished ? FloatingActionButton(tooltip: 'Tambah pekerjaan', onPressed: busy ? null : _add, child: const Icon(Icons.add)) : null,
      );
}
