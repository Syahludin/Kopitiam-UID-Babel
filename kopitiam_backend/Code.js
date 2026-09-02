var CONFIG = {
  SPREADSHEET_ID: "1PuHONGQ8ZOBQRutk9RR5-ZjFcrqW3hWfBYllQu4RUMo",
  WO_SPREADSHEET_ID: "1NYLuEIxOz8Hk4INvv8q6wq_W5CCOgfQUn7ffDgyDGy8",
  TEMUAN_SPREADSHEET_ID: "1D_WOPB75A4IJUAESrTsk5MShGmRAWlGWROqoNE-y9mw",
  USERS_SHEET: "User_App_Mobile",
  WO_INSJAR_SHEET: "WO_Ins_Jar",
  WO_INSDU_SHEET: "WO_Ins_Du",
  WO_ROW_SHEET: "WO_ROW",
  WO_HAR_JAR_SHEET: "WO_Har_Jar",
  WO_HAR_DU_SHEET: "WO_Har_Du",
  MATERIAL_HAR_JAR_SHEET: "Realisasi_Material_HarJar",
  TEMUAN_SHEET: "Inp_Temuan",
  SESSION_TTL_SEC: 900,
  MAX_LOGIN_FAILURES: 5,
  MAX_IMAGE_BYTES: 5 * 1024 * 1024,
  DRIVE_ROOT_FOLDER: "Kopitiam",
  MASTER_SHEETS: [
    "User_App_Mobile",
    "Master_Penyulang",
    "Master_Keypoint",
    "Master_Temuan",
    "Jenis Pohon",
    "Master_Material",
    "Master_Pekerjaan_Har",
    "Master_Gardu",
  ],
};

function runtimeIdentity_(body) {
  body = body || {};
  return body.deviceToken || body.token || body.username || "anonymous";
}

function revokeBoundSession_(sessionToken, deviceToken) {
  var cache = CacheService.getScriptCache();
  if (sessionToken) cache.remove("session_" + String(sessionToken).trim());
  if (deviceToken) {
    PropertiesService.getScriptProperties().deleteProperty(
      "device_" + String(deviceToken).trim(),
    );
  }
}

function verifySessionDeviceBinding_(sessionToken, session) {
  if (!session || typeof session !== "object") {
    revokeBoundSession_(sessionToken, "");
    return fail_("SESSION_BINDING_INVALID", "Sesi tidak terikat ke perangkat.");
  }
  var deviceToken = String(session.deviceToken || "").trim();
  if (!/^[a-f0-9]{64}$/i.test(deviceToken)) {
    revokeBoundSession_(sessionToken, "");
    return fail_("SESSION_BINDING_INVALID", "Sesi tidak terikat ke perangkat.");
  }
  var props = PropertiesService.getScriptProperties();
  var raw = props.getProperty("device_" + deviceToken);
  if (!raw) {
    revokeBoundSession_(sessionToken, "");
    return fail_("DEVICE_UNKNOWN", "Perangkat sesi tidak dikenali.");
  }
  var record;
  try {
    record = JSON.parse(raw);
  } catch (_) {
    revokeBoundSession_(sessionToken, deviceToken);
    return fail_("DEVICE_CORRUPT", "Data perangkat sesi rusak.");
  }
  var expiry = validateDeviceRecord_(record, Date.now());
  if (expiry) {
    revokeBoundSession_(sessionToken, deviceToken);
    return fail_(expiry, "Sesi perangkat sudah berakhir.");
  }
  if (normalize_(record.username) !== normalize_(session.username)) {
    revokeBoundSession_(sessionToken, deviceToken);
    return fail_(
      "SESSION_DEVICE_MISMATCH",
      "Sesi tidak cocok dengan perangkat.",
    );
  }
  var userRow = findUser_(session.username);
  if (!userRow) {
    revokeBoundSession_(sessionToken, deviceToken);
    return fail_("ACCOUNT_INACTIVE", "Akun tidak aktif atau tidak ditemukan.");
  }
  var currentSignature = passwordSignature_(
    String(userRow[USER_COL.password] || ""),
  );
  if (
    !constantTimeEqual_(
      currentSignature,
      String(record.passwordSignature || ""),
    )
  ) {
    revokeBoundSession_(sessionToken, deviceToken);
    return fail_(
      "DEVICE_REVOKED",
      "Kredensial akun berubah. Silakan login ulang.",
    );
  }
  var account = accountStatus_(session.username);
  if (!account.exists || !account.active) {
    revokeBoundSession_(sessionToken, deviceToken);
    return fail_("ACCOUNT_INACTIVE", "Akun tidak aktif atau tidak ditemukan.");
  }
  return { success: true, deviceToken: deviceToken };
}

var USER_COL = {
  no: 0,
  kodeUiw: 1,
  kodeUp3: 2,
  kodeUlp: 3,
  ulp: 4,
  username: 5,
  password: 6,
  role: 7,
  bidang: 8,
  tim: 9,
  subTim: 10,
  aksesMenu: 11,
};

function doGet(e) {
  var a = String((e && e.parameter && e.parameter.action) || "health").trim();
  return a === "health"
    ? json_({ success: true, service: "Kopitiam API", version: "3.0.0" })
    : json_({
        success: false,
        kode: "POST_REQUIRED",
        message: "Gunakan POST untuk operasi API.",
      });
}

function doPost(e) {
  try {
    var b = parseBody_(e),
      a = String(b.action || "").trim();
    var quota = consumeActionQuota_(a, runtimeIdentity_(b));
    if (!quota.success) return json_(quota);
    if (a === "login" || a === "loginPerangkat")
      return json_(loginPerangkat_(b.username, b.password, b.perangkat));
    if (a === "cekPerangkat") return json_(cekPerangkat_(b.deviceToken));
    if (a === "logoutPerangkat")
      return json_(logoutPerangkat_(b.deviceToken, b.token));
    if (a === "cekSesi") return json_(cekSesi_(b.token));
    if (a === "logout") return json_(logout_(b.token));
    if (a === "getMasterData") return json_(getMasterData_(b.token));
    if (a === "getWoInsjar") return json_(getWoInsjar_(b.token));
    if (a === "syncWoInsjar") return json_(syncWoInsjar_(b.token, b.rows));
    if (a === "getWoInsdu") return json_(getWoInsdu_(b.token));
    if (a === "syncWoInsdu") return json_(syncWoInsdu_(b.token, b.rows));
    if (a === "getWoRow") return json_(getWoRow_(b.token));
    if (a === "syncWoRow") return json_(syncWoRow_(b.token, b.rows));
    if (a === "getWoHarJar") return json_(getWoHarJar_(b.token));
    if (a === "syncWoHarJar") return json_(syncWoHarJar_(b.token, b.rows));
    if (a === "getWoHarDu") return json_(getWoHarDu_(b.token));
    if (a === "syncWoHarDu") return json_(syncWoHarDu_(b.token, b.rows));
    if (a === "getTemuanInspeksi")
      return json_(getTemuanInspeksi_(b.token, b.kodeWo));
    if (a === "syncTemuanInspeksi")
      return json_(syncTemuanInspeksiIdempotent_(b.token, b.row));
    return json_({
      success: false,
      kode: "ACTION_INVALID",
      message: "Action API tidak dikenal.",
    });
  } catch (x) {
    console.error(x && x.stack ? x.stack : x);
    return json_({
      success: false,
      kode: "SERVER_ERROR",
      message: "Permintaan tidak dapat diproses.",
    });
  }
}

function loginPerangkat_(u, p, d) {
  u = String(u || "").trim();
  p = String(p || "");
  if (!u || !p)
    return fail_("LOGIN_REQUIRED", "Username dan kata sandi wajib diisi.");
  var c = CacheService.getScriptCache(),
    k = "login_fail_" + sha256_(normalize_(u)).substring(0, 24),
    n = Number(c.get(k) || 0);
  if (n >= CONFIG.MAX_LOGIN_FAILURES)
    return fail_(
      "LOGIN_RATE_LIMIT",
      "Terlalu banyak percobaan. Coba lagi 5 menit.",
    );
  var r = findUser_(u),
    supplied = passwordSignature_(p),
    expected = passwordSignature_(
      r ? String(r[USER_COL.password] || "") : "__invalid_password__",
    );
  p = "";
  if (!r || !constantTimeEqual_(expected, supplied)) {
    c.put(k, String(n + 1), 300);
    return fail_("LOGIN_FAILED", "Username atau kata sandi salah.");
  }
  c.remove(k);
  r[USER_COL.password] = "";
  var dt =
      Utilities.getUuid().replace(/-/g, "") +
      Utilities.getUuid().replace(/-/g, ""),
    now = Date.now();
  evictOldestDeviceIfNeeded_(normalize_(r[USER_COL.username]));
  PropertiesService.getScriptProperties().setProperty(
    "device_" + dt,
    JSON.stringify({
      username: String(r[USER_COL.username]).trim(),
      passwordSignature: expected,
      createdAt: now,
      lastUsedAt: now,
      device: safeText_(d, 120),
    }),
  );
  var s = issueSession_(r, dt);
  s.success = true;
  s.deviceToken = dt;
  return s;
}

function cekPerangkat_(t) {
  t = String(t || "").trim();
  if (!/^[a-f0-9]{64}$/i.test(t))
    return fail_("DEVICE_INVALID", "Sesi perangkat tidak valid.");
  var p = PropertiesService.getScriptProperties(),
    key = "device_" + t,
    raw = p.getProperty(key);
  if (!raw)
    return fail_(
      "DEVICE_UNKNOWN",
      "Sesi perangkat tidak dikenali. Silakan login ulang.",
    );
  var rec;
  try {
    rec = JSON.parse(raw);
  } catch (_) {
    p.deleteProperty(key);
    return fail_(
      "DEVICE_CORRUPT",
      "Sesi perangkat rusak. Silakan login ulang.",
    );
  }
  var expiry = validateDeviceRecord_(rec, Date.now());
  if (expiry) {
    p.deleteProperty(key);
    return fail_(expiry, "Sesi perangkat sudah berakhir. Silakan login ulang.");
  }
  var account = accountStatus_(rec.username);
  if (!account.exists || !account.active) {
    p.deleteProperty(key);
    return fail_("ACCOUNT_INACTIVE", "Akun tidak aktif atau tidak ditemukan.");
  }
  var r = findUser_(rec.username),
    expected = passwordSignature_(
      r ? String(r[USER_COL.password] || "") : "__invalid_password__",
    );
  if (
    !r ||
    !constantTimeEqual_(expected, String(rec.passwordSignature || ""))
  ) {
    p.deleteProperty(key);
    return fail_("DEVICE_REVOKED", "Akun berubah. Silakan login ulang.");
  }
  r[USER_COL.password] = "";
  rec.lastUsedAt = Date.now();
  p.setProperty(key, JSON.stringify(rec));
  var s = issueSession_(r, t);
  s.success = true;
  s.deviceToken = t;
  return s;
}

function logoutPerangkat_(d, t) {
  var p = PropertiesService.getScriptProperties();
  if (d) p.deleteProperty("device_" + String(d).trim());
  if (t) CacheService.getScriptCache().remove("session_" + String(t).trim());
  return { success: true };
}

function issueSession_(r, d) {
  var t = Utilities.getUuid(),
    s = userFromRow_(r);
  s.token = t;
  s.deviceToken = d;
  s.loginAt = new Date().toISOString();
  CacheService.getScriptCache().put(
    "session_" + t,
    JSON.stringify(s),
    CONFIG.SESSION_TTL_SEC,
  );
  return s;
}

function cekSesi_(t) {
  t = String(t || "").trim();
  if (!/^[a-f0-9-]{36}$/i.test(t))
    return fail_("SESSION_INVALID", "Sesi tidak valid atau sudah berakhir.");
  var c = CacheService.getScriptCache(),
    raw = c.get("session_" + t);
  if (!raw)
    return fail_("SESSION_EXPIRED", "Sesi tidak valid atau sudah berakhir.");
  var sesi = JSON.parse(raw);
  var binding = verifySessionDeviceBinding_(t, sesi);
  if (!binding.success) return binding;
  c.put("session_" + t, raw, CONFIG.SESSION_TTL_SEC);
  return { success: true, sesi: sesi };
}

function logout_(t) {
  if (t) CacheService.getScriptCache().remove("session_" + String(t));
  return { success: true };
}

function getMasterData_(t) {
  var a = cekSesi_(t);
  if (!a.success) return a;
  var u = normalize_(a.sesi.username),
    ss = getSpreadsheet_(),
    sets = {},
    total = 0;
  for (var i = 0; i < CONFIG.MASTER_SHEETS.length; i++) {
    var n = CONFIG.MASTER_SHEETS[i],
      sh = ss.getSheetByName(n);
    if (!sh)
      return fail_("MASTER_SHEET_MISSING", "Data master belum tersedia: " + n);
    var v = sh.getDataRange().getDisplayValues(),
      h = v.length
        ? v[0].map(function (x) {
            return String(x).trim();
          })
        : [],
      rows = [];
    for (var r = 1; r < v.length; r++) {
      if (n === CONFIG.USERS_SHEET && normalize_(v[r][USER_COL.username]) !== u)
        continue;
      var item = {},
        has = false;
      for (var c = 0; c < h.length; c++) {
        var k = h[c] || "kolom_" + (c + 1);
        if (n === CONFIG.USERS_SHEET && normalize_(k) === "password") continue;
        item[k] = v[r][c];
        if (v[r][c] !== "") has = true;
      }
      if (has) rows.push(item);
    }
    sets[n] = rows;
    total += rows.length;
  }
  return {
    success: true,
    generatedAt: new Date().toISOString(),
    total: total,
    datasets: sets,
  };
}

// ----------------------------------------------------
// WO HAR (JARINGAN & GARDU)
// ----------------------------------------------------
function woHarAccess_(s, mode) {
  var sub = normalize_(s.subTim || s.tim || "");
  var u = normalize_(s.username || "");
  var k = normalizeCode_(s.kodeUlp || "");
  if (!k) return fail_("ULP_MISSING", "Kode ULP akun belum terisi.");

  var isHarGeneral = (sub === "har" || sub === "hartek" || u.indexOf(".har") >= 0 || u.indexOf(".hartek") >= 0);
  var isHarDu = (sub.indexOf("har gardu") >= 0 || sub.indexOf("hardu") >= 0 || u.indexOf(".hardu") >= 0);
  var isHarJar = (sub.indexOf("har jar") >= 0 || sub.indexOf("harjar") >= 0 || u.indexOf(".harjar") >= 0);

  if (mode === "jar") {
    if (isHarGeneral || isHarJar) return { success: true, kodeUlp: k, subTim: sub };
    return fail_("HARJAR_ACCESS_DENIED", "Akses WO Har Jar hanya untuk Tim Har Jar / Hartek.");
  }
  if (mode === "du") {
    if (isHarGeneral || isHarDu) return { success: true, kodeUlp: k, subTim: sub };
    return fail_("HARDU_ACCESS_DENIED", "Akses WO Har Du hanya untuk Tim Har Gardu / Hartek.");
  }
  return fail_("HAR_ACCESS_DENIED", "Akses ditolak.");
}

function getWoHarJar_(t) {
  var a = cekSesi_(t);
  if (!a.success) return a;
  var ac = woHarAccess_(a.sesi, "jar");
  if (!ac.success) return ac;
  var sh = SpreadsheetApp.openById(CONFIG.WO_SPREADSHEET_ID).getSheetByName(CONFIG.WO_HAR_JAR_SHEET);
  if (!sh) return { success: true, total: 0, rows: [] };
  var v = sh.getDataRange().getDisplayValues();
  if (v.length < 2) return { success: true, total: 0, rows: [] };
  var h = v[0].map(function (x) { return String(x).trim(); });
  var ix = headerIndex_(h);
  var rows = [];
  for (var r = 1; r < v.length; r++) {
    if (String(v[r][ix["kode wo"]] || "").trim() && normalizeCode_(v[r][ix["kode ulp"]]) === ac.kodeUlp) {
      rows.push(rowObject_(h, v[r]));
    }
  }
  return { success: true, total: rows.length, kodeUlpFilter: ac.kodeUlp, rows: rows };
}

function getWoHarDu_(t) {
  var a = cekSesi_(t);
  if (!a.success) return a;
  var ac = woHarAccess_(a.sesi, "du");
  if (!ac.success) return ac;
  var sh = SpreadsheetApp.openById(CONFIG.WO_SPREADSHEET_ID).getSheetByName(CONFIG.WO_HAR_DU_SHEET);
  if (!sh) return { success: true, total: 0, rows: [] };
  var v = sh.getDataRange().getDisplayValues();
  if (v.length < 2) return { success: true, total: 0, rows: [] };
  var h = v[0].map(function (x) { return String(x).trim(); });
  var ix = headerIndex_(h);
  var rows = [];
  for (var r = 1; r < v.length; r++) {
    if (String(v[r][ix["kode wo"]] || "").trim() && normalizeCode_(v[r][ix["kode ulp"]]) === ac.kodeUlp) {
      rows.push(rowObject_(h, v[r]));
    }
  }
  return { success: true, total: rows.length, kodeUlpFilter: ac.kodeUlp, rows: rows };
}

var WO_HAR_MUTABLE_HEADERS = [
  "koordinat", "lat", "long", "foto sesudah", "link foto sesudah",
  "catatan petugas", "status wo", "waktu selesai", "durasi", "user input", "waktu input", "folder path"
];

function syncWoHarJar_(t, rows) {
  var a = cekSesi_(t);
  if (!a.success) return a;
  var ac = woHarAccess_(a.sesi, "jar");
  if (!ac.success) return ac;
  return syncGenericWoHar_(a.sesi, CONFIG.WO_HAR_JAR_SHEET, rows);
}

function syncWoHarDu_(t, rows) {
  var a = cekSesi_(t);
  if (!a.success) return a;
  var ac = woHarAccess_(a.sesi, "du");
  if (!ac.success) return ac;
  return syncGenericWoHar_(a.sesi, CONFIG.WO_HAR_DU_SHEET, rows);
}

function syncGenericWoHar_(sesi, sheetName, rows) {
  if (!Array.isArray(rows) || rows.length > 100) return fail_("BATCH_INVALID", "Maksimal 100 WO.");
  var sh = SpreadsheetApp.openById(CONFIG.WO_SPREADSHEET_ID).getSheetByName(sheetName);
  if (!sh) return fail_("SHEET_NOT_FOUND", "Sheet " + sheetName + " tidak ditemukan.");
  var v = sh.getDataRange().getDisplayValues();
  if (v.length < 2) return fail_("DATA_EMPTY", "Sheet data kosong.");
  var h = v[0].map(function (x) { return String(x).trim(); });
  var ix = headerIndex_(h);
  var lock = LockService.getScriptLock();
  lock.waitLock(20000);
  try {
    var done = 0;
    for (var i = 0; i < rows.length; i++) {
      var d = rows[i] || {};
      var kodeWo = String(d["Kode WO"] || "").trim();
      var targetRow = 0;
      for (var r = 1; r < v.length; r++) {
        if (String(v[r][ix["kode wo"]] || "").trim() === kodeWo) {
          targetRow = r + 1;
          break;
        }
      }
      if (!targetRow) continue;
      var out = v[targetRow - 1].slice();
      var normPayload = {};
      for (var key in d) if (Object.prototype.hasOwnProperty.call(d, key)) normPayload[normalize_(key)] = d[key];
      for (var c = 0; c < h.length; c++) {
        var n = normalize_(h[c]);
        if (WO_HAR_MUTABLE_HEADERS.indexOf(n) >= 0 && normPayload[n] !== undefined) {
          out[c] = safeCell_(normPayload[n]);
        }
      }
      if (ix["status wo"] !== undefined) out[ix["status wo"]] = "Selesai";
      sh.getRange(targetRow, 1, 1, h.length).setValues([out]);
      done++;
    }
    SpreadsheetApp.flush();
    return { success: true, diproses: done, diperbarui: done };
  } finally {
    lock.releaseLock();
  }
}

// ----------------------------------------------------
// UTILS & USER SESSION
// ----------------------------------------------------
function findUser_(u) {
  var s = getSpreadsheet_().getSheetByName(CONFIG.USERS_SHEET);
  if (!s) throw new Error("User sheet missing");
  var r = s.getDataRange().getDisplayValues(), t = normalize_(u);
  for (var i = 1; i < r.length; i++) if (normalize_(r[i][USER_COL.username]) === t) return r[i].slice();
  return null;
}

function userFromRow_(r) {
  return {
    no: String(r[0] || ""),
    kodeUiw: String(r[1] || ""),
    kodeUp3: String(r[2] || ""),
    kodeUlp: String(r[3] || ""),
    ulp: String(r[4] || ""),
    username: String(r[5] || ""),
    role: String(r[7] || ""),
    bidang: String(r[8] || ""),
    tim: String(r[9] || ""),
    subTim: String(r[10] || ""),
    aksesMenu: String(r[11] || ""),
  };
}

function passwordPepper_() {
  var props = PropertiesService.getScriptProperties(), value = props.getProperty("PASSWORD_PEPPER");
  if (value) return value;
  var lock = LockService.getScriptLock();
  lock.waitLock(10000);
  try {
    value = props.getProperty("PASSWORD_PEPPER");
    if (!value) {
      value = Utilities.getUuid() + Utilities.getUuid() + Utilities.getUuid();
      props.setProperty("PASSWORD_PEPPER", value);
    }
    return value;
  } finally {
    lock.releaseLock();
  }
}

function passwordSignature_(v) {
  return sha256_(passwordPepper_() + "\n" + String(v || ""));
}

function headerIndex_(h) {
  var x = {};
  for (var i = 0; i < h.length; i++) x[normalize_(h[i])] = i;
  return x;
}

function rowObject_(h, r) {
  var x = {};
  for (var i = 0; i < h.length; i++) x[h[i] || "kolom_" + (i + 1)] = r[i];
  return x;
}

function numericOrBlank_(v) {
  if (v === "" || v === null || v === undefined) return "";
  var n = Number(String(v).replace(",", "."));
  if (!isFinite(n) || n < 0) throw new Error("Invalid numeric value");
  return n;
}

function safeText_(v, n) {
  return String(v || "").trim().substring(0, n);
}

function safeCell_(v) {
  var s = String(v == null ? "" : v);
  if (/^[=+\-@\t\r]/.test(s)) return "'" + s;
  return s;
}

function safePath_(v) {
  var s = String(v || "").trim().replace(/[\\/:*?"<>|\x00-\x1F]/g, "_").substring(0, 120);
  if (!s || s === "." || s === "..") throw new Error("Invalid path");
  return s;
}

function constantTimeEqual_(a, b) {
  a = String(a); b = String(b);
  var d = a.length ^ b.length, n = Math.max(a.length, b.length);
  for (var i = 0; i < n; i++) d |= (a.charCodeAt(i % (a.length || 1)) || 0) ^ (b.charCodeAt(i % (b.length || 1)) || 0);
  return d === 0;
}

function fail_(c, m) { return { success: false, kode: c, message: m }; }
function normalize_(v) { return String(v || "").trim().toLowerCase().replace(/\s+/g, " "); }
function normalizeCode_(v) { return String(v || "").trim().toUpperCase().replace(/[^A-Z0-9]/g, "").replace(/^0+/, ""); }
function getSpreadsheet_() { return SpreadsheetApp.openById(CONFIG.SPREADSHEET_ID); }
function parseBody_(e) {
  if (!e || !e.postData || !e.postData.contents) throw new Error("Empty body");
  if (e.postData.contents.length > 15 * 1024 * 1024) throw new Error("Payload too large");
  return JSON.parse(e.postData.contents);
}
function sha256_(v) {
  return Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, String(v), Utilities.Charset.UTF_8).map(function (b) { var n = b < 0 ? b + 256 : b; return ("0" + n.toString(16)).slice(-2); }).join("");
}
function json_(p) { return ContentService.createTextOutput(JSON.stringify(p)).setMimeType(ContentService.MimeType.JSON); }
function evictOldestDeviceIfNeeded_(username) {
  var MAX_DEVICE_PER_USER = 3;
  var props = PropertiesService.getScriptProperties();
  var all = props.getProperties();
  var devices = [];
  for (var key in all) {
    if (key.indexOf("device_") !== 0) continue;
    try {
      var rec = JSON.parse(all[key]);
      if (normalize_(rec.username) === username) devices.push({ key: key, lastUsedAt: Number(rec.lastUsedAt || 0) });
    } catch (_) {}
  }
  if (devices.length < MAX_DEVICE_PER_USER) return;
  devices.sort(function (a, b) { return a.lastUsedAt - b.lastUsedAt; });
  for (var i = 0; i <= devices.length - MAX_DEVICE_PER_USER; i++) props.deleteProperty(devices[i].key);
}
