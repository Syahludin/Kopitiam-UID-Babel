function temuanSheetHeaders_() {
  return [
    "No", "Kode WO", "Kode Temuan", "Kode UIW", "Kode UP3", "Kode ULP", "ULP",
    "Hari", "Tanggal", "Penyulang", "Section Awal", "Section Akhir", "Section",
    "Segmen", "Nomor Gardu", "Jenis Object", "Tier", "Temuan",
    "Jarak Terhadap Jaringan", "Jenis Pohon", "Tinggi Pohon", "Prioritas",
    "Koordinat Temuan", "Lat Temuan", "Long Temuan", "Foto Temuan", "Link Foto",
    "Foto Lingkungan Sekitaran Tiang", "Link Foto Sekitaran Tiang",
    "Pekerjaan (Padam / Tanpa Padam)", "Jenis WO", "Waktu Input", "User Input", "Folder Path"
  ];
}

function temuanSheet_() {
  var spreadsheet = SpreadsheetApp.openById(CONFIG.TEMUAN_SPREADSHEET_ID);
  var sheet = spreadsheet.getSheetByName(CONFIG.TEMUAN_SHEET || "Inp_Temuan");
  if (!sheet) {
    sheet = spreadsheet.insertSheet(CONFIG.TEMUAN_SHEET || "Inp_Temuan");
    sheet.appendRow(temuanSheetHeaders_());
    try { sheet.setFrozenRows(1); } catch (_) {}
  }
  return sheet;
}

function validateTemuanHeaders_(headers) {
  var index = headerIndex_(headers);
  var required = ["kode wo", "kode temuan", "temuan", "jenis object", "tier", "prioritas", "koordinat temuan"];
  for (var i = 0; i < required.length; i++) {
    if (index[required[i]] === undefined) {
      return fail_("SHEET_HEADERS_INVALID", "Header sheet Inp_Temuan belum valid. Kolom wajib tidak ditemukan: " + required[i] + ".");
    }
  }
  return { success: true };
}

function buildFindingPath_(kodeUlp, object, kodeWo, kodeTemuan, now) {
  var month = Utilities.formatDate(now, Session.getScriptTimeZone(), "MM");
  var year = Utilities.formatDate(now, Session.getScriptTimeZone(), "yyyy");
  var day = Utilities.formatDate(now, Session.getScriptTimeZone(), "dd");
  var monthName = Utilities.formatDate(now, Session.getScriptTimeZone(), "MM. MMMM");
  return "Kopitiam/Rekap Temuan Inspeksi/" + safePath_(kodeUlp) + "/" +
    safePath_(object) + "/" + year + "/" + monthName + "/" + day + "/" +
    safePath_(kodeWo) + "/" + safePath_(kodeTemuan) + "/";
}

function folderPath_(pathValue) {
  var root = DriveApp.getRootFolder();
  var parts = String(pathValue || "").split("/").filter(function (part) { return String(part).trim() !== ""; });
  if (parts.length && normalize_(parts[0]) === normalize_(CONFIG.DRIVE_ROOT_FOLDER || "Kopitiam")) parts.shift();
  var current = root;
  for (var i = 0; i < parts.length; i++) {
    var name = safePath_(parts[i]);
    var folders = current.getFoldersByName(name);
    current = folders.hasNext() ? folders.next() : current.createFolder(name);
  }
  return current;
}
