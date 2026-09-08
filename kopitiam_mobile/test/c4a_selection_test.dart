import 'package:flutter_test/flutter_test.dart';
import 'package:kopitiam_mobile/models/c4a_selection.dart';

const units = [
  {'Kode UIW': '16', 'Kode UP3': '161', 'Kode ULP': '16140', 'ULP': 'ULP Koba'},
  {
    'Kode UIW': '16',
    'Kode UP3': '163',
    'Kode ULP': '16310',
    'ULP': 'ULP Manggar',
  },
];

void main() {
  test(
    'master produksi hanya akun sendiri: UID dan UP3 tetap bisa cascade',
    () {
      final uid = C4aSelection(
        {'kodeUiw': '16', 'username': 'pegawai'},
        [
          {
            'Kode UIW': '16',
            'Kode UP3': '',
            'Kode ULP': '',
            'Username': 'pegawai',
          },
        ],
      );
      expect(uid.up3Options, ['161', '163']);
      uid.selectUp3('161');
      uid.selectUlp('16100');
      expect(uid.identity['kode_ulp'], '16100');
      expect(uid.identity['ulp'], 'ULP Pangkalpinang');
      final up3 = C4aSelection({'kodeUiw': '16', 'kodeUp3': '163'}, []);
      expect(up3.ulpOptions, ['16300', '16310']);
    },
  );
  test('Tier dan object difilter bersamaan lintas ULP', () {
    final rows = [
      {
        'Objek Inspeksi': 'Jaringan',
        'Tier': 'Tier 1',
        'Temuan': 'A',
        'ULP': '16310',
      },
      {'Objek Inspeksi': 'Jaringan', 'Tier': 'Tier 2', 'Temuan': 'B'},
      {'Objek Inspeksi': 'Gardu', 'Tier': 'Tier 1', 'Temuan': 'C'},
      {'Objek Inspeksi': 'Jaringan', 'Temuan': 'D'},
    ];
    expect(
      C4aSelection.temuanForTier(rows, 'Jaringan', 'Tier 1').single['Temuan'],
      'A',
    );
    expect(
      C4aSelection.temuanForTier(rows, 'Jaringan', 'Tier 2').single['Temuan'],
      'B',
    );
    expect(C4aSelection.temuanForTier(rows, 'Gardu', 'Tier 2'), isEmpty);
    expect(C4aSelection.temuanForTier(rows, 'Jaringan', null), isEmpty);
  });
  test('identitas dari unit berlaku, bukan unit akun UID; ambigu ditolak', () {
    final uid = C4aSelection({'kodeUiw': '16'}, units);
    uid.selectUp3('163');
    uid.selectUlp('16310');
    expect(uid.identity, {
      'kode_uiw': '16',
      'kode_up3': '163',
      'kode_ulp': '16310',
      'ulp': 'ULP Manggar',
    });
    final ambiguous = C4aSelection({}, [
      ...units,
      {...units.last, 'Kode UIW': '99'},
    ]);
    ambiguous.selectUp3('163');
    ambiguous.selectUlp('16310');
    expect(ambiguous.identity, isEmpty);
  });
  test('object strict: master kosong/ambigu tidak bocor ke cabang lain', () {
    final rows = [
      {'Objek Inspeksi': 'Jaringan', 'Temuan': 'A'},
      {'Objek Inspeksi': 'Gardu', 'Temuan': 'B'},
      {'Objek Inspeksi': 'Jaringan/Gardu', 'Temuan': 'C'},
      {'Temuan': 'D'},
    ];
    expect(
      C4aSelection.temuanForObject(rows, 'Jaringan').single['Temuan'],
      'A',
    );
    expect(C4aSelection.temuanForObject(rows, 'Gardu').single['Temuan'], 'B');
    expect(C4aSelection.temuanForObject(rows, ''), isEmpty);
  });
  test('gardu filter ULP dan koordinat mempertahankan desimal X/Y', () {
    final selection = C4aSelection({
      'kodeUp3': '161',
      'kodeUlp': '16140',
    }, units);
    final rows = [
      {
        'ULP': 'Koba',
        'GARDU': 'G1',
        'PENYULANG': 'A',
        'PTS/LBS': 'K1',
        'X': '-2.123456789',
        'Y': '106.123456789',
      },
      {'ULP': 'Manggar', 'GARDU': 'G2'},
    ];
    expect(selection.garduOptions(rows), ['G1']);
    final row = selection.gardu(rows, 'G1')!;
    expect(C4aSelection.latitude(row), '-2.123456789');
    expect(C4aSelection.longitude(row), '106.123456789');
    expect(selection.gardu(rows, 'G2'), isNull);
    expect(C4aSelection.validCoordinate('106', '-2'), false);
    expect(C4aSelection.validCoordinate('NaN', '106'), false);
  });
  test(
    'master jaringan filter ULP kode/nama dan penyulang, gabungan section',
    () {
      final selection = C4aSelection({
        'kodeUp3': '161',
        'kodeUlp': '16140',
      }, units);
      expect(
        selection.penyulangOptions([
          {'ULP': 'Koba', 'Nama Penyulang': 'A'},
          {'ULP': '16140', 'Nama Penyulang': 'B'},
          {'ULP': 'ULP Manggar', 'Nama Penyulang': 'C'},
        ]),
        ['A', 'B'],
      );
      expect(
        selection.sectionOptions([
          {'ULP': 'ULP Koba', 'Penyulang': 'A', 'NAMA KEYPOINT': 'K1'},
          {'ULP': '16140', 'Penyulang': 'B', 'NAMA KEYPOINT': 'K2'},
          {'ULP': '16310', 'Penyulang': 'A', 'NAMA KEYPOINT': 'K3'},
        ], 'A'),
        ['K1'],
      );
      expect(C4aSelection.section('K1', 'K2'), 'K1 - K2');
      expect(C4aSelection.section('K1', 'K1'), '');
    },
  );
  test('cascade UID, UP3, ULP dan Super User menyimpan kode numerik', () {
    final uid = C4aSelection({}, units);
    expect(uid.isUid, true);
    uid.selectUp3('161');
    uid.selectUlp('16140');
    expect(uid.ready, true);
    uid.selectUp3('163');
    expect(uid.ulp, isNull);
    expect(uid.ulpOptions, ['16300', '16310']);
    uid.selectUlp('16140');
    expect(uid.ready, false);
    final up3 = C4aSelection({'kodeUp3': '161'}, units);
    up3.selectUp3('163');
    expect(up3.up3, '161');
    up3.selectUlp('16310');
    expect(up3.ulp, isNull);
    final ulp = C4aSelection({'kodeUp3': '161', 'kodeUlp': '16140'}, []);
    expect(ulp.isUlp, true);
    expect(ulp.ready, true);
    final superUser = C4aSelection({
      'role': 'Super User',
      'kodeUp3': '161',
      'kodeUlp': '16140',
    }, units);
    expect(superUser.isUid, true);
    expect(superUser.ulp, isNull);
    expect(C4aSelection.ulpLabels['16100'], 'ULP Pangkalpinang');
  });
}
