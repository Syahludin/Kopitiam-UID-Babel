class WoMaterialHarJar {
  static const kepemilikanOptions = ['PLN', 'Mitra', 'Bongkaran'];
  static const satuanOptions = ['Pcs', 'Meter', 'Set', 'Batang'];

  final int? id;
  final String kodePenggunaanMaterial;
  final String kodeWo;
  final String material;
  final double jumlah;
  final String satuan;
  final String kepemilikan;
  final String keterangan;
  final String userInput;
  final String waktuInput;
  final bool isSynced;

  const WoMaterialHarJar({
    this.id,
    required this.kodePenggunaanMaterial,
    required this.kodeWo,
    this.material = '',
    this.jumlah = 0,
    this.satuan = '',
    this.kepemilikan = '',
    this.keterangan = '',
    this.userInput = '',
    this.waktuInput = '',
    this.isSynced = false,
  });

  factory WoMaterialHarJar.fromMap(Map<String, Object?> m) =>
      WoMaterialHarJar(
        id: m['id'] as int?,
        kodePenggunaanMaterial: '${m['kode_penggunaan_material'] ?? ''}',
        kodeWo: '${m['kode_wo'] ?? ''}',
        material: '${m['material'] ?? ''}',
        jumlah: (m['jumlah'] as num?)?.toDouble() ?? 0,
        satuan: '${m['satuan'] ?? ''}',
        kepemilikan: '${m['kepemilikan'] ?? ''}',
        keterangan: '${m['keterangan'] ?? ''}',
        userInput: '${m['user_input'] ?? ''}',
        waktuInput: '${m['waktu_input'] ?? ''}',
        isSynced: m['is_synced'] == 1,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'kode_penggunaan_material': kodePenggunaanMaterial,
        'kode_wo': kodeWo,
        'material': material,
        'jumlah': jumlah,
        'satuan': satuan,
        'kepemilikan': kepemilikan,
        'keterangan': keterangan,
        'user_input': userInput,
        'waktu_input': waktuInput,
        'is_synced': isSynced ? 1 : 0,
      };

  Map<String, dynamic> toRemote() => {
        'Kode Penggunaan Material': kodePenggunaanMaterial,
        'Kode WO': kodeWo,
        'Material': material,
        'Jumlah': jumlah,
        'Satuan': satuan,
        'Kepemilikan': kepemilikan,
        'Keterangan': keterangan,
        'User Input': userInput,
        'Waktu Input': waktuInput,
      };

  WoMaterialHarJar copyWith({
    String? material,
    double? jumlah,
    String? satuan,
    String? kepemilikan,
    String? keterangan,
    bool? isSynced,
  }) =>
      WoMaterialHarJar(
        id: id,
        kodePenggunaanMaterial: kodePenggunaanMaterial,
        kodeWo: kodeWo,
        material: material ?? this.material,
        jumlah: jumlah ?? this.jumlah,
        satuan: satuan ?? this.satuan,
        kepemilikan: kepemilikan ?? this.kepemilikan,
        keterangan: keterangan ?? this.keterangan,
        userInput: userInput,
        waktuInput: waktuInput,
        isSynced: isSynced ?? this.isSynced,
      );
}
