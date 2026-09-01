import 'package:flutter/material.dart';

import '../models/wo_material_har_jar.dart';

class MaterialItemCard extends StatelessWidget {
  static const navy = Color(0xFF071B30);
  static const muted = Color(0xFF64748B);
  static const line = Color(0xFFE2E8F0);
  static const red = Color(0xFFDC2626);

  final WoMaterialHarJar item;
  final VoidCallback? onDelete;

  const MaterialItemCard({
    super.key,
    required this.item,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.material,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: navy,
                  ),
                ),
                if (item.keterangan.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.keterangan,
                    style: const TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_formatJumlah(item.jumlah)} ${item.satuan}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: navy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.kepemilikan,
                style: const TextStyle(fontSize: 10, color: muted),
              ),
            ],
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 4),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, color: red, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ],
      ),
    );
  }

  String _formatJumlah(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }
}

class MaterialInputSection extends StatefulWidget {
  static const blue = Color(0xFF0A3E74);
  static const navy = Color(0xFF071B30);
  static const muted = Color(0xFF64748B);
  static const line = Color(0xFFE2E8F0);

  final List<WoMaterialHarJar> materials;
  final List<String> masterMaterials;
  final bool editable;
  final void Function(WoMaterialHarJar item) onAdd;
  final void Function(String kodePenggunaanMaterial) onDelete;

  const MaterialInputSection({
    super.key,
    required this.materials,
    required this.masterMaterials,
    required this.editable,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  State<MaterialInputSection> createState() => _MaterialInputSectionState();
}

class _MaterialInputSectionState extends State<MaterialInputSection> {
  Future<void> _tambahMaterial() async {
    if (!widget.editable) return;
    final result = await showModalBottomSheet<WoMaterialHarJar>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AddMaterialBottomSheet(
        masterMaterials: widget.masterMaterials,
      ),
    );
    if (result != null) widget.onAdd(result);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MaterialInputSection.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Penggunaan Material',
            style: TextStyle(
              color: MaterialInputSection.blue,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (widget.materials.isEmpty)
            const Text(
              'Belum ada material ditambahkan.',
              style: TextStyle(fontSize: 12, color: MaterialInputSection.muted),
            )
          else
            ...widget.materials.map(
              (item) => MaterialItemCard(
                item: item,
                onDelete: widget.editable
                    ? () => widget.onDelete(item.kodePenggunaanMaterial)
                    : null,
              ),
            ),
          if (widget.editable) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _tambahMaterial,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'Tambah Material',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MaterialInputSection.blue,
                  side: const BorderSide(color: MaterialInputSection.line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AddMaterialBottomSheet extends StatefulWidget {
  final List<String> masterMaterials;

  const AddMaterialBottomSheet({
    super.key,
    required this.masterMaterials,
  });

  @override
  State<AddMaterialBottomSheet> createState() => _AddMaterialBottomSheetState();
}

class _AddMaterialBottomSheetState extends State<AddMaterialBottomSheet> {
  static const blue = Color(0xFF0A3E74);
  static const line = Color(0xFFE2E8F0);

  final _jumlahCtrl = TextEditingController();
  final _keteranganCtrl = TextEditingController();
  String? _material;
  String? _satuan;
  String? _kepemilikan;

  @override
  void dispose() {
    _jumlahCtrl.dispose();
    _keteranganCtrl.dispose();
    super.dispose();
  }

  void _simpan() {
    final jumlah = double.tryParse(_jumlahCtrl.text.replaceAll(',', '.'));
    if (_material == null || _material!.isEmpty) {
      _pesan('Pilih material terlebih dahulu.');
      return;
    }
    if (jumlah == null || jumlah <= 0) {
      _pesan('Isi jumlah material dengan angka valid.');
      return;
    }
    if (_satuan == null || _satuan!.isEmpty) {
      _pesan('Pilih satuan material.');
      return;
    }
    if (_kepemilikan == null || _kepemilikan!.isEmpty) {
      _pesan('Pilih kepemilikan material.');
      return;
    }
    Navigator.pop(
      context,
      WoMaterialHarJar(
        kodePenggunaanMaterial: '',
        kodeWo: '',
        material: _material!,
        jumlah: jumlah,
        satuan: _satuan!,
        kepemilikan: _kepemilikan!,
        keterangan: _keteranganCtrl.text.trim(),
      ),
    );
  }

  void _pesan(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tambah Material',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Autocomplete<String>(
            optionsBuilder: (value) {
              final query = value.text.toLowerCase();
              if (query.isEmpty) return widget.masterMaterials;
              return widget.masterMaterials
                  .where((item) => item.toLowerCase().contains(query));
            },
            onSelected: (value) => setState(() => _material = value),
            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: _inputDecoration('Material *'),
                onChanged: (value) => _material = value.trim(),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _jumlahCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDecoration('Jumlah *'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _satuan,
                  hint: const Text('Satuan'),
                  items: WoMaterialHarJar.satuanOptions
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _satuan = value),
                  decoration: _inputDecoration('Satuan *'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _kepemilikan,
            hint: const Text('Kepemilikan'),
            items: WoMaterialHarJar.kepemilikanOptions
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _kepemilikan = value),
            decoration: _inputDecoration('Kepemilikan *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _keteranganCtrl,
            decoration: _inputDecoration('Keterangan (opsional)'),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _simpan,
              style: FilledButton.styleFrom(
                backgroundColor: blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Tambahkan',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: blue, width: 1.5),
        ),
      );
}
