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

function preparePhoto_(base64Value, role) {
  if (!base64Value) throw new Error(role + " required");
  var encoded = String(base64Value);
  if (encoded.length > Math.ceil((CONFIG.MAX_IMAGE_BYTES * 4) / 3) + 16) {
    throw new Error(role + " too large");
  }
  var bytes;
  try {
    bytes = Utilities.base64Decode(encoded);
  } catch (_) {
    throw new Error(role + " invalid base64");
  }
  if (bytes.length > CONFIG.MAX_IMAGE_BYTES)
    throw new Error(role + " too large");
  validateJpegBytes_(bytes);
  return { role: role, bytes: bytes, digest: digestBytes_(bytes) };
}

function digestBytes_(bytes) {
  return Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, bytes)
    .map(function (value) {
      var byte = value < 0 ? value + 256 : value;
      return ("0" + byte.toString(16)).slice(-2);
    })
    .join("");
}

function putPhotoIdempotent_(folder, code, prepared) {
  var filename = safePath_(code + "." + prepared.role + "." + prepared.digest.substring(0, 24) + ".jpg");
  var matches = folder.getFilesByName(filename);
  if (matches.hasNext()) {
    var existing = matches.next();
    return { file: existing, name: existing.getName(), url: existing.getUrl(), digest: prepared.digest, created: false };
  }
  var created = folder.createFile(Utilities.newBlob(prepared.bytes, "image/jpeg", filename));
  return { file: created, name: created.getName(), url: created.getUrl(), digest: prepared.digest, created: true };
}

function rollbackCreatedPhotos_(photos) {
  (photos || []).forEach(function (photo) {
    if (!photo || !photo.created || !photo.file) return;
    try { photo.file.setTrashed(true); } catch (_) {}
  });
}

function removeStalePhotos_(folder, code, keepNames) {
  var prefix = code + ".", files = folder.getFiles();
  while (files.hasNext()) {
    var file = files.next(), name = file.getName();
    if (name.indexOf(prefix) !== 0 || keepNames.indexOf(name) >= 0) continue;
    if (name.indexOf(".Foto Temuan.") < 0 && name.indexOf(".Foto Lingkungan.") < 0) continue;
    try { file.setTrashed(true); } catch (_) {}
  }
}

function photoIdempotencyKey_(code, primary, environment) {
  return sha256_(code + "|" + primary.digest + "|" + environment.digest).substring(0, 40);
}

function syncTemuanInspeksiIdempotent_(token, incoming) {
  var auth = cekSesi_(token);
  if (!auth.success) return auth;
  if (!incoming || typeof incoming !== "object") return fail_("FINDING_REQUIRED", "Data temuan kosong.");
  var master = validateFindingMaster_(safeText_(incoming["Jenis Object"], 40), safeText_(incoming["Tier"], 20), safeText_(incoming["Temuan"], 200), safeText_(incoming["Prioritas"], 20));
  if (!master.success) return master;
  var kodeWo = safeText_(incoming["Kode WO"], 100), code = safeText_(incoming["Kode Temuan"], 120);
  if (code.indexOf(kodeWo + ".TO-") !== 0 || !/^[0-9]{3}$/.test(code.substring((kodeWo + ".TO-").length))) return fail_("FINDING_CODE_INVALID", "Kode Temuan tidak valid.");
  var tier = safeText_(incoming["Tier"], 20), object = safeText_(incoming["Jenis Object"], 40);
  if (tier !== "Tier 1" && tier !== "Tier 2") return fail_("TIER_INVALID", "Tier tidak valid.");
  var sub = normalize_(auth.sesi.subTim || auth.sesi.tim), expected = object;
  if (sub.indexOf("inspeksi jaringan") >= 0 || sub.indexOf("insjar") >= 0) expected = "Jaringan";
  else if (sub.indexOf("inspeksi gardu") >= 0 || sub.indexOf("insdu") >= 0) expected = "Gardu";
  else if (object !== "Jaringan" && object !== "Gardu") return fail_("OBJECT_INVALID", "Jenis Object harus Jaringan atau Gardu.");
  if (expected !== object) return fail_("OBJECT_MISMATCH", "Jenis Object tidak sesuai Sub-Tim.");
  var finding = safeText_(incoming["Temuan"], 200), segment = safeText_(incoming["Segmen"], 200);
  if (!finding || !segment) return fail_("FINDING_INVALID", "Data wajib temuan belum valid.");
  var point, primaryPrepared, environmentPrepared;
  try {
    point = validateCoordinate_(safeText_(incoming["Koordinat Temuan"], 80));
    primaryPrepared = preparePhoto_(incoming.fotoTemuanBase64, "Foto Temuan");
    environmentPrepared = preparePhoto_(incoming.fotoLingkunganBase64, "Foto Lingkungan");
  } catch (_) { return fail_("INPUT_INVALID", "Koordinat atau file foto tidak valid."); }
  var lock = LockService.getScriptLock(), created = [];
  lock.waitLock(30000);
  try {
    var context = woContext_(auth.sesi, kodeWo, true);
    if (!context.success) return context;
    var now = new Date(), index = context.index, server = context.row, row = {};
    row["Kode WO"] = kodeWo; row["Kode Temuan"] = code;
    row["Kode UIW"] = server[index["kode uiw"]] || auth.sesi.kodeUiw || "";
    row["Kode UP3"] = server[index["kode up3"]] || auth.sesi.kodeUp3 || "";
    row["Kode ULP"] = context.kodeUlp; row["ULP"] = server[index.ulp] || auth.sesi.ulp || "";
    row["Hari"] = ["Minggu", "Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu"][now.getDay()];
    row["Tanggal"] = Utilities.formatDate(now, Session.getScriptTimeZone(), "dd MMMM yyyy");
    row["Penyulang"] = server[index.penyulang] || ""; row["Section Awal"] = server[index["section awal"]] || "";
    row["Section Akhir"] = server[index["section akhir"]] || ""; row["Section"] = server[index.section] || "";
    row["Segmen"] = segment; row["Koordinat Temuan"] = point.latitude + ", " + point.longitude;
    row["Lat Temuan"] = point.latitude; row["Long Temuan"] = point.longitude; row["Jenis Object"] = object;
    row["Tier"] = tier; row["Temuan"] = finding; row["Jarak Terhadap Jaringan"] = numericOrBlank_(incoming["Jarak Terhadap Jaringan"]);
    row["Jenis Pohon"] = safeText_(incoming["Jenis Pohon"], 100); row["Tinggi Pohon"] = numericOrBlank_(incoming["Tinggi Pohon"]);
    row["Prioritas"] = safeText_(incoming["Prioritas"], 20); row["Pekerjaan (Padam / Tanpa Padam)"] = ""; row["Jenis WO"] = "";
    row["Waktu Input"] = Utilities.formatDate(now, Session.getScriptTimeZone(), "dd MMMM yyyy, HH:mm:ss"); row["User Input"] = auth.sesi.username;
    row["Folder Path"] = buildFindingPath_(context.kodeUlp, object, kodeWo, code, now);
    var sheet = temuanSheet_(), values = sheet.getDataRange().getValues();
    var headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getDisplayValues()[0], headerValidation = validateTemuanHeaders_(headers);
    if (!headerValidation.success) return headerValidation;
    var headerIndex = headerIndex_(headers), target = 0;
    for (var r = 1; r < values.length; r++) if (String(values[r][headerIndex["kode temuan"]] || "") === code) { target = r + 1; break; }
    var folder = folderPath_(row["Folder Path"]), primary = putPhotoIdempotent_(folder, code, primaryPrepared); created.push(primary);
    var environment = putPhotoIdempotent_(folder, code, environmentPrepared); created.push(environment);
    row["Foto Temuan"] = primary.name; row["Link Foto"] = primary.url; row["Foto Lingkungan Sekitaran Tiang"] = environment.name; row["Link Foto Sekitaran Tiang"] = environment.url;
    var normalizedRow = {};
    for (var key in row) if (Object.prototype.hasOwnProperty.call(row, key)) normalizedRow[normalize_(key)] = row[key];
    var output = headers.map(function (header) { var value = normalizedRow[normalize_(header)]; return value === undefined || value === null ? "" : safeCell_(value); });
    var firstHeader = normalize_(headers[0] || ""), numberColumn = firstHeader === "no" || firstHeader === "no." || firstHeader === "nomor";
    if (target) { if (numberColumn) output[0] = values[target - 1][0]; sheet.getRange(target, 1, 1, headers.length).setValues([output]); }
    else { if (numberColumn) output[0] = sheet.getLastRow(); sheet.appendRow(output); }
    SpreadsheetApp.flush(); removeStalePhotos_(folder, code, [primary.name, environment.name]);
    return { success: true, linkFoto: primary.url, linkLingkungan: environment.url, folderPath: row["Folder Path"], idempotencyKey: photoIdempotencyKey_(code, primary, environment), reused: !primary.created && !environment.created };
  } catch (err) {
    console.error("syncTemuanInspeksi idempotent gagal:", err && err.stack ? err.stack : err);
    rollbackCreatedPhotos_(created);
    var detail = String((err && err.message) || err || "").replace(/\s+/g, " ").trim().substring(0, 280);
    return fail_("SYNC_TRANSACTION_FAILED", detail ? "Sinkronisasi gagal: " + detail : "Sinkronisasi gagal dan file baru dibatalkan.");
  } finally { lock.releaseLock(); }
}
