var CONFIG = {
  SPREADSHEET_ID: '18mVJgfMaPjs8ppmlhf5JVYvHhysHYy9L77bwfRPI5O0',
  WO_SPREADSHEET_ID: '15T21iCLPb8vwzFNtUbWjZ_T3RGGDZ-Y9UX5-4UV1Zgk',
  TEMUAN_SPREADSHEET_ID: '1qFBQq3hMTA98ZV6UWg-Pj5sz-J41pm0r13TLYP2LF0I',
  USERS_SHEET: 'User_App_Mobile',
  WO_INSJAR_SHEET: 'WO_Ins_Jar',
  TEMUAN_SHEET: 'Inp_Temuan',
  SESSION_TTL_SEC: 900,
  MAX_LOGIN_FAILURES: 5,
  MAX_IMAGE_BYTES: 5 * 1024 * 1024,
  MASTER_SHEETS: ['User_App_Mobile', 'Master_Penyulang', 'Master_Keypoint', 'List_Temuan', 'Jenis Pohon']
};

var USER_COL = { no: 0, kodeUiw: 1, kodeUp3: 2, kodeUlp: 3, ulp: 4, username: 5, password: 6, role: 7, bidang: 8, tim: 9, subTim: 10, aksesMenu: 11 };
var WO_MUTABLE_HEADERS = ['koordinat awal', 'koordinat akhir', 'realisasi kms', 'waktu mulai', 'waktu selesai', 'durasi pekerjaan', 'status wo'];

function doGet(e) {
  var action = String((e && e.parameter && e.parameter.action) || 'health').trim();
  if (action === 'health') return json_({ success: true, service: 'SiManDist API', version: '2.5.0' });
  return json_({ success: false, kode: 'POST_REQUIRED', message: 'Gunakan POST untuk operasi API.' });
}

function doPost(e) {
  try {
    var body = parseBody_(e);
    var action = String(body.action || '').trim();
    if (action === 'login' || action === 'loginPerangkat') return json_(loginPerangkat_(body.username, body.password, body.perangkat));
    if (action === 'cekPerangkat') return json_(cekPerangkat_(body.deviceToken));
    if (action === 'logoutPerangkat') return json_(logoutPerangkat_(body.deviceToken, body.token));
    if (action === 'cekSesi') return json_(cekSesi_(body.token));
    if (action === 'logout') return json_(logout_(body.token));
    if (action === 'getMasterData') return json_(getMasterData_(body.token));
    if (action === 'getWoInsjar') return json_(getWoInsjar_(body.token));
    if (action === 'syncWoInsjar') return json_(syncWoInsjar_(body.token, body.rows));
    if (action === 'getTemuanInspeksi') return json_(getTemuanInspeksi_(body.token, body.kodeWo));
    if (action === 'syncTemuanInspeksi') return json_(syncTemuanInspeksi_(body.token, body.row));
    return json_({ success: false, kode: 'ACTION_INVALID', message: 'Action API tidak dikenal.' });
  } catch (error) {
    console.error(error && error.stack ? error.stack : error);
    return json_({ success: false, kode: 'SERVER_ERROR', message: 'Permintaan tidak dapat diproses.' });
  }
}

function loginPerangkat_(username, password, perangkat) {
  username = String(username || '').trim();
  password = String(password || '');
  if (!username || !password) return fail_('LOGIN_REQUIRED', 'Username dan kata sandi wajib diisi.');
  if (username.length > 80 || password.length > 200) return fail_('LOGIN_INVALID', 'Format akun tidak valid.');

  var cache = CacheService.getScriptCache();
  var failureKey = 'login_fail_' + sha256_(normalize_(username)).substring(0, 24);
  var failures = Number(cache.get(failureKey) || 0);
  if (failures >= CONFIG.MAX_LOGIN_FAILURES) return fail_('LOGIN_RATE_LIMIT', 'Terlalu banyak percobaan. Coba lagi 5 menit.');

  var row = findUser_(username);
  var valid = row && constantTimeEqual_(String(row[USER_COL.password] || ''), password);
  if (!valid) {
    cache.put(failureKey, String(failures + 1), 300);
    return fail_('LOGIN_FAILED', 'Username atau kata sandi salah.');
  }
  cache.remove(failureKey);

  var deviceToken = Utilities.getUuid().replace(/-/g, '') + Utilities.getUuid().replace(/-/g, '');
  var now = Date.now();
  PropertiesService.getScriptProperties().setProperty('device_' + deviceToken, JSON.stringify({
    username: String(row[USER_COL.username]).trim(),
    passwordSignature: sha256_(password),
    createdAt: now,
    lastUsedAt: now,
    device: safeText_(perangkat, 120)
  }));
  var session = issueSession_(row, deviceToken);
  session.success = true;
  session.deviceToken = deviceToken;
  return session;
}

function cekPerangkat_(deviceToken) {
  deviceToken = String(deviceToken || '').trim();
  if (!/^[a-f0-9]{64}$/i.test(deviceToken)) return fail_('DEVICE_INVALID', 'Sesi perangkat tidak valid.');
  var props = PropertiesService.getScriptProperties();
  var raw = props.getProperty('device_' + deviceToken);
  if (!raw) return fail_('DEVICE_UNKNOWN', 'Sesi perangkat tidak dikenali. Silakan login ulang.');
  var record = JSON.parse(raw);
  var row = findUser_(record.username);
  if (!row || sha256_(String(row[USER_COL.password] || '')) !== String(record.passwordSignature || '')) {
    props.deleteProperty('device_' + deviceToken);
    return fail_('DEVICE_REVOKED', 'Akun berubah. Silakan login ulang.');
  }
  record.lastUsedAt = Date.now();
  props.setProperty('device_' + deviceToken, JSON.stringify(record));
  var session = issueSession_(row, deviceToken);
  session.success = true;
  session.deviceToken = deviceToken;
  return session;
}

function logoutPerangkat_(deviceToken, token) {
  var props = PropertiesService.getScriptProperties();
  if (deviceToken) props.deleteProperty('device_' + String(deviceToken).trim());
  if (token) CacheService.getScriptCache().remove('session_' + String(token).trim());
  return { success: true };
}

function issueSession_(row, deviceToken) {
  var token = Utilities.getUuid();
  var session = userFromRow_(row);
  session.token = token;
  session.deviceToken = deviceToken;
  session.loginAt = new Date().toISOString();
  CacheService.getScriptCache().put('session_' + token, JSON.stringify(session), CONFIG.SESSION_TTL_SEC);
  return session;
}

function cekSesi_(token) {
  token = String(token || '').trim();
  if (!/^[a-f0-9-]{36}$/i.test(token)) return fail_('SESSION_INVALID', 'Sesi tidak valid atau sudah berakhir.');
  var cache = CacheService.getScriptCache();
  var raw = cache.get('session_' + token);
  if (!raw) return fail_('SESSION_EXPIRED', 'Sesi tidak valid atau sudah berakhir.');
  cache.put('session_' + token, raw, CONFIG.SESSION_TTL_SEC);
  return { success: true, sesi: JSON.parse(raw) };
}

function logout_(token) {
  if (token) CacheService.getScriptCache().remove('session_' + String(token));
  return { success: true };
}

function getMasterData_(token) {
  var auth = cekSesi_(token);
  if (!auth.success) return auth;
  var username = normalize_(auth.sesi.username);
  var ss = getSpreadsheet_();
  var datasets = {};
  var total = 0;
  for (var i = 0; i < CONFIG.MASTER_SHEETS.length; i++) {
    var name = CONFIG.MASTER_SHEETS[i];
    var sheet = ss.getSheetByName(name);
    if (!sheet) return fail_('MASTER_SHEET_MISSING', 'Data master belum tersedia.');
    var values = sheet.getDataRange().getDisplayValues();
    var headers = values.length ? values[0].map(function(value) { return String(value).trim(); }) : [];
    var rows = [];
    for (var r = 1; r < values.length; r++) {
      if (name === CONFIG.USERS_SHEET && normalize_(values[r][USER_COL.username]) !== username) continue;
      var item = {};
      var hasValue = false;
      for (var c = 0; c < headers.length; c++) {
        var key = headers[c] || ('kolom_' + (c + 1));
        if (name === CONFIG.USERS_SHEET && normalize_(key) === 'password') continue;
        item[key] = values[r][c];
        if (values[r][c] !== '') hasValue = true;
      }
      if (hasValue) rows.push(item);
    }
    datasets[name] = rows;
    total += rows.length;
  }
  return { success: true, generatedAt: new Date().toISOString(), total: total, datasets: datasets };
}

function woAccess_(session) {
  var subTeam = normalize_(session.subTim || session.tim);
  if (subTeam.indexOf('inspeksi jaringan') < 0 && subTeam.indexOf('insjar') < 0) {
    return fail_('WO_ACCESS_DENIED', 'WO Inspeksi Jaringan hanya tersedia untuk Sub-Tim Inspeksi Jaringan.');
  }
  var kodeUlp = normalizeCode_(session.kodeUlp);
  if (!kodeUlp) return fail_('ULP_MISSING', 'Kode ULP akun belum terisi.');
  return { success: true, kodeUlp: kodeUlp };
}

function woSheet_() {
  var sheet = SpreadsheetApp.openById(CONFIG.WO_SPREADSHEET_ID).getSheetByName(CONFIG.WO_INSJAR_SHEET);
  if (!sheet) throw new Error('WO sheet missing');
  return sheet;
}

function woContext_(session, kodeWo, requireEditable) {
  var access = woAccess_(session);
  if (!access.success) return access;
  kodeWo = safeText_(kodeWo, 100);
  if (!kodeWo) return fail_('WO_REQUIRED', 'Kode WO wajib diisi.');
  var sheet = woSheet_();
  var values = sheet.getDataRange().getDisplayValues();
  if (values.length < 2) return fail_('WO_NOT_FOUND', 'WO tidak ditemukan.');
  var headers = values[0].map(function(value) { return String(value).trim(); });
  var index = headerIndex_(headers);
  var codeIndex = index['kode wo'];
  var ulpIndex = index['kode ulp'];
  var statusIndex = index['status wo'];
  if (codeIndex === undefined || ulpIndex === undefined || statusIndex === undefined) throw new Error('WO headers invalid');
  for (var r = 1; r < values.length; r++) {
    if (String(values[r][codeIndex] || '').trim() !== kodeWo) continue;
    if (normalizeCode_(values[r][ulpIndex]) !== access.kodeUlp) return fail_('WO_OWNERSHIP_DENIED', 'WO bukan milik ULP akun ini.');
    var status = normalize_(values[r][statusIndex]);
    if (requireEditable && status === 'selesai') return fail_('WO_LOCKED', 'WO sudah selesai dan hanya dapat dilihat.');
    return { success: true, sheet: sheet, headers: headers, index: index, row: values[r], rowNumber: r + 1, status: status, kodeUlp: access.kodeUlp };
  }
  return fail_('WO_NOT_FOUND', 'WO tidak ditemukan.');
}

function getWoInsjar_(token) {
  var auth = cekSesi_(token);
  if (!auth.success) return auth;
  var access = woAccess_(auth.sesi);
  if (!access.success) return access;
  var sheet = woSheet_();
  var values = sheet.getDataRange().getDisplayValues();
  if (values.length < 2) return { success: true, total: 0, totalSheet: 0, rows: [] };
  var headers = values[0].map(function(value) { return String(value).trim(); });
  var index = headerIndex_(headers);
  if (index['kode wo'] === undefined || index['kode ulp'] === undefined) throw new Error('WO headers invalid');
  var rows = [];
  var validRows = 0;
  for (var r = 1; r < values.length; r++) {
    if (!String(values[r][index['kode wo']] || '').trim()) continue;
    validRows++;
    if (normalizeCode_(values[r][index['kode ulp']]) !== access.kodeUlp) continue;
    rows.push(rowObject_(headers, values[r]));
  }
  return { success: true, total: rows.length, totalSheet: validRows, kodeUlpFilter: access.kodeUlp, rows: rows };
}

function syncWoInsjar_(token, rows) {
  var auth = cekSesi_(token);
  if (!auth.success) return auth;
  if (!Array.isArray(rows) || !rows.length) return { success: true, diproses: 0 };
  if (rows.length > 100) return fail_('BATCH_TOO_LARGE', 'Maksimal 100 WO per sinkronisasi.');
  var lock = LockService.getScriptLock();
  lock.waitLock(20000);
  try {
    var updated = 0;
    for (var i = 0; i < rows.length; i++) {
      var incoming = rows[i] || {};
      var context = woContext_(auth.sesi, incoming['Kode WO'], true);
      if (!context.success) return context;
      var target = context.row.slice();
      for (var c = 0; c < context.headers.length; c++) {
        var normalized = normalize_(context.headers[c]);
        if (WO_MUTABLE_HEADERS.indexOf(normalized) < 0) continue;
        if (incoming[context.headers[c]] !== undefined && incoming[context.headers[c]] !== null) target[c] = incoming[context.headers[c]];
      }
      var nextStatus = normalize_(target[context.index['status wo']]);
      if (['mulai pengerjaan', 'dalam pengerjaan', 'selesai'].indexOf(nextStatus) < 0) return fail_('STATUS_INVALID', 'Status WO tidak valid.');
      context.sheet.getRange(context.rowNumber, 1, 1, context.headers.length).setValues([target]);
      updated++;
    }
    SpreadsheetApp.flush();
    return { success: true, diproses: updated, diperbarui: updated, ditambahkan: 0 };
  } finally {
    lock.releaseLock();
  }
}

function temuanSheet_() {
  var sheet = SpreadsheetApp.openById(CONFIG.TEMUAN_SPREADSHEET_ID).getSheetByName(CONFIG.TEMUAN_SHEET);
  if (!sheet) throw new Error('Findings sheet missing');
  return sheet;
}

function getTemuanInspeksi_(token, kodeWo) {
  var auth = cekSesi_(token);
  if (!auth.success) return auth;
  var context = woContext_(auth.sesi, kodeWo, false);
  if (!context.success) return context;
  var sheet = temuanSheet_();
  var values = sheet.getDataRange().getDisplayValues();
  if (values.length < 2) return { success: true, total: 0, rows: [] };
  var headers = values[0].map(function(value) { return String(value).trim(); });
  var index = headerIndex_(headers);
  if (index['kode wo'] === undefined || index['kode ulp'] === undefined) throw new Error('Finding headers invalid');
  var rows = [];
  for (var r = 1; r < values.length; r++) {
    if (String(values[r][index['kode wo']] || '').trim() !== String(kodeWo).trim()) continue;
    if (normalizeCode_(values[r][index['kode ulp']]) !== context.kodeUlp) continue;
    rows.push(rowObject_(headers, values[r]));
  }
  return { success: true, total: rows.length, rows: rows };
}

function syncTemuanInspeksi_(token, incoming) {
  var auth = cekSesi_(token);
  if (!auth.success) return auth;
  if (!incoming || typeof incoming !== 'object') return fail_('FINDING_REQUIRED', 'Data temuan kosong.');
  var kodeWo = safeText_(incoming['Kode WO'], 100);
  var context = woContext_(auth.sesi, kodeWo, true);
  if (!context.success) return context;

  var kodeTemuan = safeText_(incoming['Kode Temuan'], 120);
  var expectedPrefix = kodeWo + '.TO-';
  if (kodeTemuan.indexOf(expectedPrefix) !== 0 || !/^\d{3}$/.test(kodeTemuan.substring(expectedPrefix.length))) {
    return fail_('FINDING_CODE_INVALID', 'Kode Temuan tidak valid.');
  }
  var tier = safeText_(incoming['Tier'], 20);
  if (tier !== 'Tier 1' && tier !== 'Tier 2') return fail_('TIER_INVALID', 'Tier tidak valid.');
  var temuan = safeText_(incoming['Temuan'], 200);
  var segmen = safeText_(incoming['Segmen'], 200);
  var coordinate = safeText_(incoming['Koordinat Temuan'], 80);
  if (!temuan || !segmen || !/^-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?$/.test(coordinate)) {
    return fail_('FINDING_INVALID', 'Data wajib temuan belum valid.');
  }

  var serverRow = context.row;
  var wi = context.index;
  var now = new Date();
  var folderPath = buildFindingPath_(context.kodeUlp, 'Jaringan', kodeWo, kodeTemuan, now);
  var row = {};
  row['Kode WO'] = kodeWo;
  row['Kode Temuan'] = kodeTemuan;
  row['Kode UIW'] = serverRow[wi['kode uiw']] || auth.sesi.kodeUiw || '';
  row['Kode UP3'] = serverRow[wi['kode up3']] || auth.sesi.kodeUp3 || '';
  row['Kode ULP'] = context.kodeUlp;
  row['ULP'] = serverRow[wi['ulp']] || auth.sesi.ulp || '';
  row['Hari'] = ['Minggu','Senin','Selasa','Rabu','Kamis','Jumat','Sabtu'][now.getDay()];
  row['Tanggal'] = Utilities.formatDate(now, Session.getScriptTimeZone(), 'dd MMMM yyyy');
  row['Penyulang'] = serverRow[wi['penyulang']] || '';
  row['Section Awal'] = serverRow[wi['section awal']] || '';
  row['Section Akhir'] = serverRow[wi['section akhir']] || '';
  row['Section'] = serverRow[wi['section']] || '';
  row['Segmen'] = segmen;
  row['Koordinat Temuan'] = coordinate;
  var parts = coordinate.split(',');
  row['Lat Temuan'] = Number(parts[0].trim());
  row['Long Temuan'] = Number(parts[1].trim());
  row['Jenis Object'] = 'Jaringan';
  row['Tier'] = tier;
  row['Temuan'] = temuan;
  row['Jarak Terhadap Jaringan'] = numericOrBlank_(incoming['Jarak Terhadap Jaringan']);
  row['Jenis Pohon'] = safeText_(incoming['Jenis Pohon'], 100);
  row['Tinggi Pohon'] = numericOrBlank_(incoming['Tinggi Pohon']);
  row['Prioritas'] = safeText_(incoming['Prioritas'], 20);
  row['Pekerjaan (Padam / Tanpa Padam)'] = '';
  row['Jenis WO'] = '';
  row['Waktu Input'] = Utilities.formatDate(now, Session.getScriptTimeZone(), 'dd MMMM yyyy, HH:mm:ss');
  row['User Input'] = auth.sesi.username;
  row['Folder Path'] = folderPath;

  var folder = folderPath_(folderPath);
  var linkFoto = saveImage_(folder, incoming.fotoTemuanBase64, kodeTemuan + '.Foto Temuan.' + Utilities.formatDate(now, Session.getScriptTimeZone(), 'HHmmss') + '.jpg');
  var linkLingkungan = saveImage_(folder, incoming.fotoLingkunganBase64, kodeTemuan + '.Foto Lingkungan.' + Utilities.formatDate(now, Session.getScriptTimeZone(), 'HHmmss') + '.jpg');
  if (!linkFoto) return fail_('PHOTO_REQUIRED', 'Foto Temuan wajib diunggah.');
  row['Foto Temuan'] = linkFoto.name;
  row['Link Foto'] = linkFoto.url;
  if (linkLingkungan) {
    row['Foto Lingkungan Sekitaran Tiang'] = linkLingkungan.name;
    row['Link Foto Sekitaran Tiang'] = linkLingkungan.url;
  }

  var sheet = temuanSheet_();
  var values = sheet.getDataRange().getValues();
  var headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getDisplayValues()[0];
  var index = headerIndex_(headers);
  if (index['kode temuan'] === undefined) throw new Error('Finding key missing');
  var targetRow = 0;
  for (var r = 1; r < values.length; r++) {
    if (String(values[r][index['kode temuan']] || '') === kodeTemuan) { targetRow = r + 1; break; }
  }
  var output = headers.map(function(header) { return row[header] === undefined || row[header] === null ? '' : row[header]; });
  if (targetRow) {
    output[0] = values[targetRow - 1][0];
    sheet.getRange(targetRow, 1, 1, headers.length).setValues([output]);
  } else {
    output[0] = sheet.getLastRow();
    sheet.appendRow(output);
  }
  return { success: true, linkFoto: row['Link Foto'], linkLingkungan: row['Link Foto Sekitaran Tiang'] || '', folderPath: folderPath };
}

function saveImage_(folder, base64, name) {
  if (!base64) return null;
  base64 = String(base64);
  if (base64.length > Math.ceil(CONFIG.MAX_IMAGE_BYTES * 4 / 3) + 16) throw new Error('Image too large');
  var bytes = Utilities.base64Decode(base64);
  if (bytes.length > CONFIG.MAX_IMAGE_BYTES) throw new Error('Image too large');
  var file = folder.createFile(Utilities.newBlob(bytes, 'image/jpeg', name));
  return { name: file.getName(), url: file.getUrl() };
}

function buildFindingPath_(kodeUlp, objectName, kodeWo, kodeTemuan, date) {
  var month = Utilities.formatDate(date, Session.getScriptTimeZone(), 'MM');
  var monthNames = ['Januari','Februari','Maret','April','Mei','Juni','Juli','Agustus','September','Oktober','November','Desember'];
  var monthName = monthNames[Number(month) - 1];
  return ['SiManDist','Rekap Temuan Inspeksi',safePath_(kodeUlp),safePath_(objectName),Utilities.formatDate(date,Session.getScriptTimeZone(),'yyyy'),month + '. ' + monthName,Utilities.formatDate(date,Session.getScriptTimeZone(),'dd'),safePath_(kodeWo),safePath_(kodeTemuan)].join('/') + '/';
}

function folderPath_(path) {
  var parts = String(path || '').split('/').filter(String);
  if (parts.length < 2 || parts[0] !== 'SiManDist' || parts[1] !== 'Rekap Temuan Inspeksi' || parts.length > 10) throw new Error('Invalid folder path');
  var folder = DriveApp.getRootFolder();
  for (var i = 0; i < parts.length; i++) {
    var part = safePath_(parts[i]);
    var iterator = folder.getFoldersByName(part);
    folder = iterator.hasNext() ? iterator.next() : folder.createFolder(part);
  }
  return folder;
}

function findUser_(username) {
  var rows = getUsersRows_();
  var target = normalize_(username);
  for (var i = 1; i < rows.length; i++) if (normalize_(rows[i][USER_COL.username]) === target) return rows[i];
  return null;
}

function userFromRow_(row) {
  return { no: String(row[0] || ''), kodeUiw: String(row[1] || ''), kodeUp3: String(row[2] || ''), kodeUlp: String(row[3] || ''), ulp: String(row[4] || ''), username: String(row[5] || ''), role: String(row[7] || ''), bidang: String(row[8] || ''), tim: String(row[9] || ''), subTim: String(row[10] || ''), aksesMenu: String(row[11] || '') };
}

function getUsersRows_() {
  var cache = CacheService.getScriptCache();
  var hit = cache.get('users_v2');
  if (hit) try { return JSON.parse(hit); } catch (_) {}
  var sheet = getSpreadsheet_().getSheetByName(CONFIG.USERS_SHEET);
  if (!sheet) throw new Error('User sheet missing');
  var rows = sheet.getDataRange().getDisplayValues();
  try { cache.put('users_v2', JSON.stringify(rows), 300); } catch (_) {}
  return rows;
}

function headerIndex_(headers) {
  var index = {};
  for (var i = 0; i < headers.length; i++) index[normalize_(headers[i])] = i;
  return index;
}
function rowObject_(headers, row) { var item = {}; for (var i = 0; i < headers.length; i++) item[headers[i] || ('kolom_' + (i + 1))] = row[i]; return item; }
function numericOrBlank_(value) { if (value === '' || value === null || value === undefined) return ''; var number = Number(String(value).replace(',', '.')); if (!isFinite(number) || number < 0) throw new Error('Invalid numeric value'); return number; }
function safeText_(value, maxLength) { return String(value || '').trim().substring(0, maxLength); }
function safePath_(value) { var result = String(value || '').trim().replace(/[\\/:*?"<>|\x00-\x1F]/g, '_').substring(0, 120); if (!result || result === '.' || result === '..') throw new Error('Invalid path'); return result; }
function constantTimeEqual_(a, b) { a = String(a); b = String(b); var diff = a.length ^ b.length; var length = Math.max(a.length, b.length); for (var i = 0; i < length; i++) diff |= (a.charCodeAt(i % (a.length || 1)) || 0) ^ (b.charCodeAt(i % (b.length || 1)) || 0); return diff === 0; }
function fail_(code, message) { return { success: false, kode: code, message: message }; }
function normalize_(value) { return String(value || '').trim().toLowerCase().replace(/\s+/g, ' '); }
function normalizeCode_(value) { return String(value || '').trim().toUpperCase().replace(/[^A-Z0-9]/g, '').replace(/^0+/, ''); }
function getSpreadsheet_() { return SpreadsheetApp.openById(CONFIG.SPREADSHEET_ID); }
function parseBody_(e) { if (!e || !e.postData || !e.postData.contents) throw new Error('Empty body'); if (e.postData.contents.length > 15 * 1024 * 1024) throw new Error('Payload too large'); return JSON.parse(e.postData.contents); }
function sha256_(value) { return Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, String(value), Utilities.Charset.UTF_8).map(function(byte) { var normalized = byte < 0 ? byte + 256 : byte; return ('0' + normalized.toString(16)).slice(-2); }).join(''); }
function json_(payload) { return ContentService.createTextOutput(JSON.stringify(payload)).setMimeType(ContentService.MimeType.JSON); }
