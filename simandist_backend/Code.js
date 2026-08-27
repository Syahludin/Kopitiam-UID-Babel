var CONFIG = {
  SPREADSHEET_ID: '18mVJgfMaPjs8ppmlhf5JVYvHhysHYy9L77bwfRPI5O0',
  USERS_SHEET: 'User_App_Mobile',
  SESSION_TTL_SEC: 900,
  DEVICE_MAX_PER_USER: 5,
  MASTER_SHEETS: ['User_App_Mobile', 'Master_Penyulang', 'Master_Keypoint', 'Listr_Temuan', 'Jenis Pohon']
};

var USER_COL = { no: 0, kodeUiw: 1, kodeUp3: 2, kodeUlp: 3, ulp: 4, username: 5, password: 6, role: 7, bidang: 8, tim: 9, subTim: 10, aksesMenu: 11 };

function doGet(e) {
  var p = (e && e.parameter) || {};
  var action = String(p.action || 'health').trim();
  try {
    if (action === 'health') return json_({ success: true, service: 'SiManDist API', version: '2.1.0' });
    if (action === 'loginPerangkat') return json_(loginPerangkat_(p.username, p.password, p.perangkat));
    if (action === 'cekPerangkat') return json_(cekPerangkat_(p.deviceToken));
    if (action === 'logoutPerangkat') return json_(logoutPerangkat_(p.deviceToken, p.token));
    if (action === 'cekSesi') return json_(cekSesi_(p.token));
    if (action === 'logout') return json_(logout_(p.token));
    if (action === 'getMasterData') return json_(getMasterData_(p.token));
    return json_({ success: false, message: 'Action API tidak dikenal: ' + action });
  } catch (err) { return json_({ success: false, message: 'Error server: ' + err.message }); }
}

function doPost(e) {
  try {
    var body = parseBody_(e), action = String(body.action || '').trim();
    if (action === 'login' || action === 'loginPerangkat') return json_(loginPerangkat_(body.username, body.password, body.perangkat));
    if (action === 'cekPerangkat') return json_(cekPerangkat_(body.deviceToken));
    if (action === 'logoutPerangkat') return json_(logoutPerangkat_(body.deviceToken, body.token));
    if (action === 'cekSesi') return json_(cekSesi_(body.token));
    if (action === 'logout') return json_(logout_(body.token));
    if (action === 'getMasterData') return json_(getMasterData_(body.token));
    return json_({ success: false, message: 'Action API tidak dikenal: ' + action });
  } catch (err) { return json_({ success: false, message: 'Error server: ' + err.message }); }
}

function loginPerangkat_(username, password, perangkat) {
  username = String(username || '').trim(); password = String(password || '');
  if (!username || !password) return { success: false, message: 'Username dan kata sandi wajib diisi.' };
  var row = findUser_(username);
  if (!row || String(row[USER_COL.password] || '') !== password) return { success: false, message: 'Username atau kata sandi salah.' };
  var deviceToken = Utilities.getUuid().replace(/-/g, '') + Utilities.getUuid().replace(/-/g, '');
  var now = Date.now();
  PropertiesService.getScriptProperties().setProperty('device_' + deviceToken, JSON.stringify({ username: String(row[USER_COL.username]).trim(), passwordSignature: sha256_(password), createdAt: now, lastUsedAt: now, device: String(perangkat || '').substring(0, 100) }));
  var session = issueSession_(row, deviceToken); session.success = true; session.deviceToken = deviceToken;
  return session;
}

function cekPerangkat_(deviceToken) {
  deviceToken = String(deviceToken || '').trim();
  if (!deviceToken) return { success: false, kode: 'TANPA_TOKEN', message: 'Belum ada sesi perangkat.' };
  var props = PropertiesService.getScriptProperties(), raw = props.getProperty('device_' + deviceToken);
  if (!raw) return { success: false, kode: 'PERANGKAT_TIDAK_DIKENAL', message: 'Sesi perangkat tidak dikenali. Silakan login ulang.' };
  var rec = JSON.parse(raw), row = findUser_(rec.username);
  if (!row) { props.deleteProperty('device_' + deviceToken); return { success: false, kode: 'AKUN_TIDAK_ADA', message: 'Akun sudah tidak terdaftar.' }; }
  if (sha256_(String(row[USER_COL.password] || '')) !== String(rec.passwordSignature || '')) { props.deleteProperty('device_' + deviceToken); return { success: false, kode: 'PASSWORD_BERUBAH', message: 'Password berubah. Silakan login ulang.' }; }
  rec.lastUsedAt = Date.now(); props.setProperty('device_' + deviceToken, JSON.stringify(rec));
  var session = issueSession_(row, deviceToken); session.success = true; session.deviceToken = deviceToken; return session;
}

function logoutPerangkat_(deviceToken, token) {
  var props = PropertiesService.getScriptProperties();
  if (deviceToken) props.deleteProperty('device_' + String(deviceToken).trim());
  if (token) CacheService.getScriptCache().remove('session_' + String(token).trim());
  return { success: true };
}

function issueSession_(row, deviceToken) {
  var token = Utilities.getUuid(), session = userFromRow_(row);
  session.token = token; session.deviceToken = deviceToken; session.loginAt = new Date().toISOString();
  CacheService.getScriptCache().put('session_' + token, JSON.stringify(session), CONFIG.SESSION_TTL_SEC);
  return session;
}

function cekSesi_(token) {
  var raw = token ? CacheService.getScriptCache().get('session_' + String(token)) : null;
  if (!raw) return { success: false, message: 'Sesi tidak valid atau sudah berakhir.' };
  CacheService.getScriptCache().put('session_' + token, raw, CONFIG.SESSION_TTL_SEC);
  return { success: true, sesi: JSON.parse(raw) };
}

function logout_(token) { if (token) CacheService.getScriptCache().remove('session_' + String(token)); return { success: true }; }

function getMasterData_(token) {
  var session = cekSesi_(token);
  if (session.success !== true) return session;
  var ss = getSpreadsheet_(), datasets = {}, total = 0;
  for (var i = 0; i < CONFIG.MASTER_SHEETS.length; i++) {
    var name = CONFIG.MASTER_SHEETS[i], sheet = ss.getSheetByName(name);
    if (!sheet) return { success: false, message: 'Sheet tidak ditemukan: ' + name };
    var values = sheet.getDataRange().getDisplayValues();
    if (!values.length) { datasets[name] = []; continue; }
    var headers = values[0].map(function (v) { return String(v).trim(); });
    var rows = [];
    for (var r = 1; r < values.length; r++) {
      var item = {}, hasValue = false;
      for (var c = 0; c < headers.length; c++) {
        var key = headers[c] || ('kolom_' + (c + 1));
        if (name === CONFIG.USERS_SHEET && key.toLowerCase() === 'password') continue;
        item[key] = values[r][c];
        if (values[r][c] !== '') hasValue = true;
      }
      if (hasValue) rows.push(item);
    }
    datasets[name] = rows; total += rows.length;
  }
  return { success: true, generatedAt: new Date().toISOString(), total: total, datasets: datasets };
}

function findUser_(username) {
  var rows = getUsersRows_(), target = String(username || '').trim().toLowerCase();
  for (var i = 1; i < rows.length; i++) if (String(rows[i][USER_COL.username] || '').trim().toLowerCase() === target) return rows[i];
  return null;
}

function userFromRow_(row) {
  return { no: String(row[USER_COL.no] || ''), kodeUiw: String(row[USER_COL.kodeUiw] || ''), kodeUp3: String(row[USER_COL.kodeUp3] || ''), kodeUlp: String(row[USER_COL.kodeUlp] || ''), ulp: String(row[USER_COL.ulp] || ''), username: String(row[USER_COL.username] || ''), role: String(row[USER_COL.role] || ''), bidang: String(row[USER_COL.bidang] || ''), tim: String(row[USER_COL.tim] || ''), subTim: String(row[USER_COL.subTim] || ''), aksesMenu: String(row[USER_COL.aksesMenu] || '') };
}

function getUsersRows_() {
  var cache = CacheService.getScriptCache(), hit = cache.get('users_v2');
  if (hit) { try { return JSON.parse(hit); } catch (_) {} }
  var sheet = getSpreadsheet_().getSheetByName(CONFIG.USERS_SHEET);
  if (!sheet) throw new Error('Sheet ' + CONFIG.USERS_SHEET + ' tidak ditemukan.');
  var rows = sheet.getDataRange().getDisplayValues();
  try { cache.put('users_v2', JSON.stringify(rows), 300); } catch (_) {}
  return rows;
}

function getSpreadsheet_() { return SpreadsheetApp.openById(CONFIG.SPREADSHEET_ID); }
function parseBody_(e) { return e && e.postData && e.postData.contents ? JSON.parse(e.postData.contents) : {}; }
function sha256_(value) { var bytes = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, String(value), Utilities.Charset.UTF_8); return bytes.map(function (b) { var v = b < 0 ? b + 256 : b; return ('0' + v.toString(16)).slice(-2); }).join(''); }
function json_(payload) { return ContentService.createTextOutput(JSON.stringify(payload)).setMimeType(ContentService.MimeType.JSON); }
