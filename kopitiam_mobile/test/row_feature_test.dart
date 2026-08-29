import 'package:flutter_test/flutter_test.dart';

import 'package:kopitiam_mobile/models/wo_row.dart';

void main() {
  group('Audit ROW: model dari sheet WO_ROW (data dummy)', () {
    test('fromRemote memetakan baris WO_ROW utuh', () {
      final row = WoRow.fromRemote({
        'No': '1',
        'Kode WO': 'ROW-2026-001',
        'Kode Temuan': 'PLG-2026-001.TO-001',
        'Jenis WO': 'Inspeksi ROW',
        'Kode UIW': 'UIW001',
        'Kode UP3': 'UP3001',
        'Kode ULP': 'PLG',
        'ULP': 'ULP PLG',
        'Pekerjaan (Padam / Tanpa Padam)': 'Tanpa Padam',
        'Hari': 'Jumat',
        'Tanggal': '29 Agustus 2026',
        'Penyulang': 'PY-1',
        'Section Awal': 'A-01-01',
        'Section Akhir': 'A-01-03',
        'Section': 'A-01-02',
        'Segmen': 'A-04/A-05',
        'Jenis Object': 'Jaringan',
        'Tier': 'Tier 1',
        'Temuan': 'Rabas / Pangkas',
        'Prioritas': 'Minor',
        'Koordinat': '-6.12345, 106.23456',
        'Lat': '-6.12345',
        'Long': '106.23456',
        'Jarak Terhadap Jaringan': '2,5',
        'Jenis Pohon': 'Sengon',
        'Tinggi Pohon': '6',
        'Tim Eksekusi': 'ROW 01',
        'Tindak Lanjut': '',
        'Ukuran Diamter Batan (cm)': '',
        'Jenis Tebangan': '',
        'Status WO': 'Penugasan Tim',
        'User Input': '',
        'Waktu Input': '',
        'Waktu Realisasi': '',
        'Folder Path': 'SiManDist/Rekap Temuan Inspeksi/PLG/Jaringan/2026/08. Agustus/29/PLG-2026-001/PLG-2026-001.TO-001/',
      });
      expect(row.kodeWo, 'ROW-2026-001');
      expect(row.kodeTemuan, 'PLG-2026-001.TO-001');
      expect(row.jenisWo, 'Inspeksi ROW');
      expect(row.sectionAwal, 'A-01-01');
      expect(row.sectionAkhir, 'A-01-03');
      expect(row.pekerjaan, 'Tanpa Padam');
      expect(row.timEksekusi, 'ROW 01');
      expect(row.koordinat, '-6.12345, 106.23456');
      expect(row.jarak, 2.5);
      expect(row.tinggiPohon, 6);
      expect(row.statusWo, WoRow.statusPenugasan);
      expect(row.isDirty, false);
      expect(row.folderPath, contains('Rekap Temuan Inspeksi'));
    });

    test('normalisasiStatus mengenali ketiga status ROW', () {
      expect(
        WoRow.normalisasiStatus('Penugasan Tim'),
        WoRow.statusPenugasan,
      );
      expect(
        WoRow.normalisasiStatus('Progress Pekerjaan'),
        WoRow.statusProgress,
      );
      expect(WoRow.normalisasiStatus('berjalan'), WoRow.statusProgress);
      expect(WoRow.normalisasiStatus('SELESAI'), WoRow.statusSelesai);
    });

    test('jenis tebangan mengikuti formula IFS diameter', () {
      expect(WoRow.jenisTebanganDariDiameter(0), 'Rabas / Pangkas');
      expect(WoRow.jenisTebanganDariDiameter(null), 'Rabas / Pangkas');
      expect(WoRow.jenisTebanganDariDiameter(1), 'Tebang Sedang');
      expect(WoRow.jenisTebanganDariDiameter(50), 'Tebang Sedang');
      expect(WoRow.jenisTebanganDariDiameter(51), 'Tebang Besar');
    });

    test('toRemote memuat kolom inputan lembar realisasi ROW', () {
      final row = WoRow(
        kodeWo: 'ROW-2026-002',
        kodeTemuan: 'PLG-2026-002.TO-001',
        tindakLanjut: 'Tebang',
        ukuranDiameterBatang: 60,
        jenisTebangan: 'Tebang Besar',
        fotoSesudah: 'a.jpg',
        statusWo: WoRow.statusSelesai,
        userInput: 'petugas',
        waktuRealisasi: '29 Agustus 2026, 10:00:00',
        folderPath: 'SiManDist/...',
      );
      final remote = row.toRemote();
      expect(remote['Kode WO'], 'ROW-2026-002');
      expect(remote['Kode Temuan'], 'PLG-2026-002.TO-001');
      expect(remote['Tindak Lanjut'], 'Tebang');
      expect(remote['Ukuran Diamter Batan (cm)'], 60);
      expect(remote['Jenis Tebangan'], 'Tebang Besar');
      expect(remote['Foto Sesudah'], 'a.jpg');
      expect(remote['Status WO'], WoRow.statusSelesai);
      expect(remote['Waktu Realisasi'], '29 Agustus 2026, 10:00:00');
      expect(remote['Folder Path'], 'SiManDist/...');
      expect(remote['Koordinat'], '');
    });

    test('toMap/fromMap round-trip mempertahankan status & dirty', () {
      final row = WoRow(
        kodeWo: 'ROW-2026-003',
        tindakLanjut: 'Rabas',
        ukuranDiameterBatang: 12,
        jenisTebangan: 'Tebang Sedang',
        statusWo: WoRow.statusProgress,
        isDirty: true,
      );
      final back = WoRow.fromMap(row.toMap());
      expect(back.kodeWo, row.kodeWo);
      expect(back.ukuranDiameterBatang, 12);
      expect(back.tindakLanjut, 'Rabas');
      expect(back.statusWo, WoRow.statusProgress);
      expect(back.isDirty, true);
    });
  });
}
