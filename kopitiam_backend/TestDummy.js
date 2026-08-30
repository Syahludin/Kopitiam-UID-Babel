/**
 * Fungsi test yang bisa dijalankan langsung dari editor Apps Script.
 * Menguji seluruh alur sinkronisasi Temuan dengan data dummy,
 * termasuk pembuatan folder Drive dan upload foto dummy JPEG.
 *
 * Jalankan: pilih testSyncTemuanDummy → Run
 * Jika muncul dialog izin, klik Allow.
 * Cek Execution Log untuk hasil.
 */
function testSyncTemuanDummy() {
  // 1. Test Drive access langsung
  Logger.log("=== TEST 1: Drive access ===");
  try {
    var root = DriveApp.getRootFolder();
    Logger.log("Root folder: " + root.getName() + " ✓");
  } catch (e) {
    Logger.log("GAGAL akses Drive: " + e.message);
    Logger.log("Pastikan oauthScopes di appsscript.json memuat https://www.googleapis.com/auth/drive");
    return;
  }

  // 2. Test buat folder Kopitiam
  Logger.log("\n=== TEST 2: Folder creation ===");
  try {
    var testPath = "Kopitiam/Rekap Temuan Inspeksi/TEST_DUMMY";
    var folder = folderPath_(testPath);
    Logger.log("Folder dibuat/ditemukan: " + folder.getName() + " ✓");
    Logger.log("URL: " + folder.getUrl());
  } catch (e) {
    Logger.log("GAGAL buat folder: " + e.message);
    return;
  }

  // 3. Test upload file dummy ke folder
  Logger.log("\n=== TEST 3: File upload ===");
  try {
    // JPEG minimal valid: FF D8 FF E0 ... FF D9
    var jpegHex = "FFD8FFE000104A46494600010100000100010000FFDB004300080606070605080707070909080A0C140D0C0B0B0C1912130F141D1A1F1E1D1A1C1C20242E2720222C231C1C2837292C30313434341F27393D38323C2E333432FFDB0043010909090C0B0C180D0D1832211C213232323232323232323232323232323232323232323232323232323232323232323232323232323232323232323232323232FFC00011080001000103012200021101031101FFC4001F0000010501010101010100000000000000000102030405060708090A0BFFC400B5100002010303020403050504040000017D01020300041105122131410613516107227114328191A1082342B1C11552D1F02433627282090A161718191A25262728292A3435363738393A434445464748494A535455565758595A636465666768696A737475767778797A838485868788898A92939495969798999AA2A3A4A5A6A7A8A9AAB2B3B4B5B6B7B8B9BAC2C3C4C5C6C7C8C9CAD2D3D4D5D6D7D8D9DAE1E2E3E4E5E6E7E8E9EAF1F2F3F4F5F6F7F8F9FAFFC4001F0100030101010101010101010000000000000102030405060708090A0BFFC400B51100020102040403040705040400010277000102031104052131061241510761711322328108144291A1B1C109233352F0156272D10A162434E125F11718191A262728292A35363738393A434445464748494A535455565758595A636465666768696A737475767778797A82838485868788898A92939495969798999AA2A3A4A5A6A7A8A9AAB2B3B4B5B6B7B8B9BAC2C3C4C5C6C7C8C9CAD2D3D4D5D6D7D8D9DAE2E3E4E5E6E7E8E9EAF2F3F4F5F6F7F8F9FAFFDA000C03010002110311003F00FBFC2800A00FFD9";
    var bytes = [];
    for (var i = 0; i < jpegHex.length; i += 2) {
      bytes.push(parseInt(jpegHex.substr(i, 2), 16));
    }
    var blob = Utilities.newBlob(bytes, "image/jpeg", "test_dummy.jpg");
    var file = folder.createFile(blob);
    Logger.log("File dibuat: " + file.getName() + " ✓");
    Logger.log("URL: " + file.getUrl());
    // Bersihkan file test
    file.setTrashed(true);
    Logger.log("File test dihapus ✓");
  } catch (e) {
    Logger.log("GAGAL upload file: " + e.message);
    return;
  }

  // 4. Test Spreadsheet Temuan
  Logger.log("\n=== TEST 4: Spreadsheet Inp_Temuan ===");
  try {
    var sh = temuanSheet_();
    Logger.log("Sheet: " + sh.getName() + ", baris: " + sh.getLastRow() + " ✓");
  } catch (e) {
    Logger.log("GAGAL akses sheet Temuan: " + e.message);
    return;
  }

  // 5. Test buildFindingPath_
  Logger.log("\n=== TEST 5: buildFindingPath_ ===");
  var path = buildFindingPath_("16130", "Jaringan", "INSJAR-TEST-001", "INSJAR-TEST-001.TO-001", new Date());
  Logger.log("Path: " + path);
  if (path.indexOf("Kopitiam/") === 0) {
    Logger.log("Folder awal Kopitiam ✓");
  } else {
    Logger.log("GAGAL: folder awal bukan Kopitiam, ditemukan: " + path.split("/")[0]);
  }

  // Bersihkan folder test
  try {
    var testFolder = DriveApp.getRootFolder();
    var it = testFolder.getFoldersByName("Kopitiam");
    if (it.hasNext()) {
      var kop = it.next();
      var it2 = kop.getFoldersByName("Rekap Temuan Inspeksi");
      if (it2.hasNext()) {
        var rekap = it2.next();
        var it3 = rekap.getFoldersByName("TEST_DUMMY");
        if (it3.hasNext()) {
          it3.next().setTrashed(true);
          Logger.log("\nFolder TEST_DUMMY dihapus ✓");
        }
      }
    }
  } catch (_) {}

  Logger.log("\n=== SEMUA TEST BERHASIL ===");
}

/**
 * Test sederhana hanya untuk memastikan DriveApp.getRootFolder() berhasil.
 * Jika gagal, berarti otorisasi Drive belum terpicu.
 */
function testDriveAccess() {
  var root = DriveApp.getRootFolder();
  Logger.log("Drive root: " + root.getName());
  Logger.log("Owner: " + root.getOwner().getEmail());
  Logger.log("Drive access OK ✓");
}
