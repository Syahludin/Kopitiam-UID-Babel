import 'package:flutter/material.dart';

import '../models/wo_har_du.dart';
import '../services/wo_har_du_repository.dart';
import '../widgets/wo_har_du_card.dart';
import 'form_tindak_lanjut_har_du_screen.dart';
import 'settings_session_section.dart';
import 'widgets/operation_result_dialog.dart';
import 'widgets/welcome_card.dart';
import 'widgets/wo_data_card.dart';
import 'widgets/wo_summary_card.dart';

class HarDuDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> sesi;

  const HarDuDashboardScreen({super.key, required this.sesi});

  @override
  State<HarDuDashboardScreen> createState() => _HarDuDashboardScreenState();
}

class _HarDuDashboardScreenState extends State<HarDuDashboardScreen> {
  final _repository = WoHarDuRepository();
  List<WoHarDu> _items = const [];
  int _selected = 1;

  String get _token => '${widget.sesi['token'] ?? ''}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _repository.semua();
    if (mounted) setState(() => _items = items);
  }

  void _showResultLater({
    required bool success,
    required String title,
    required String message,
  }) {
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      showOperationResultDialog(
        context,
        success: success,
        title: title,
        message: message,
      );
    });
  }

  Future<void> _download() async {
    final result = await _repository.download(_token);
    await _load();
    if (result.pesan != null) {
      _showResultLater(
        success: false,
        title: 'Download Gagal',
        message: result.pesan!,
      );
      throw StateError(result.pesan!);
    }
    _showResultLater(
      success: result.diproses > 0,
      title: result.diproses > 0 ? 'Download Selesai' : 'Tidak Ada Data Baru',
      message: result.diproses > 0
          ? '${result.diproses} WO Har Du disimpan ke perangkat.'
          : 'Total WO yang lolos filter: ${result.total}.',
    );
  }

  Future<void> _sync() async {
    final result = await _repository.sinkron(_token);
    await _load();
    if (result.pesan != null) {
      _showResultLater(
        success: false,
        title: 'Sinkronisasi Gagal',
        message: result.pesan!,
      );
      throw StateError(result.pesan!);
    }
    _showResultLater(
      success: true,
      title: 'Sinkronisasi Selesai',
      message: '${result.diproses} WO Har Du dikirim ke server.',
    );
  }

  Future<void> _open(WoHarDu item, {bool start = false}) async {
    if (start) await _repository.mulaiPekerjaan(item.kodeWo);
    final current = await _repository.cari(item.kodeWo) ?? item;
    if (!mounted) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FormTindakLanjutHarDuScreen(
          existing: current,
          sesi: widget.sesi,
        ),
      ),
    );
    if (changed == true || start) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _items
        .where((item) =>
            WoHarDu.normalisasiStatus(item.statusWo) == WoHarDu.statusMenunggu)
        .length;
    final progress = _items
        .where((item) =>
            WoHarDu.normalisasiStatus(item.statusWo) == WoHarDu.statusSedang)
        .length;
    final done = _items
        .where((item) =>
            WoHarDu.normalisasiStatus(item.statusWo) == WoHarDu.statusSelesai)
        .length;
    final dirty = _items
        .where((item) =>
            !item.isSynced &&
            WoHarDu.normalisasiStatus(item.statusWo) == WoHarDu.statusSelesai)
        .length;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          const ['Work Order Har Du', 'Beranda', 'Pengaturan'][_selected],
        ),
      ),
      body: IndexedStack(
        index: _selected,
        children: [
          RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: _items.isEmpty
                  ? const [
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 50),
                        child: Center(
                          child: Text('Belum ada WO Har Du di perangkat'),
                        ),
                      ),
                    ]
                  : _items
                      .map(
                        (item) => WoHarDuCard(
                          wo: item,
                          onKerjakan: () => _open(item, start: true),
                          onLanjut: () => _open(item),
                        ),
                      )
                      .toList(),
            ),
          ),
          ListView(
            padding: const EdgeInsets.all(18),
            children: [
              WelcomeCard(sesi: widget.sesi),
              const SizedBox(height: 16),
              WoDataCard(
                isRow: false,
                dirty: dirty,
                onDownload: _download,
                onSync: _sync,
              ),
              const SizedBox(height: 16),
              WoSummaryCard.insjar(
                total: _items.length,
                menunggu: waiting,
                sedang: progress,
                selesai: done,
              ),
            ],
          ),
          ListView(
            padding: const EdgeInsets.all(18),
            children: [SettingsSessionSection(session: widget.sesi)],
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selected,
        onDestinationSelected: (value) => setState(() => _selected = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.assignment_rounded),
            label: 'Work Order',
          ),
          NavigationDestination(
            icon: Icon(Icons.home_rounded),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_rounded),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }
}
