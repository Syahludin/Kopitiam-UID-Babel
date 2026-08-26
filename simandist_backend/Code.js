var CONFIG = {
  SPREADSHEET_ID: '18mVJgfMaPjs8ppmlhf5JVYvHhysHYy9L77bwfRPI5O0',
  USERS_SHEET: 'User_App_Mobile',
  SESSIONS_SHEET: 'db_Sessions',
  SESSION_DAYS: 30
};

var USER_COL = {
  no: 0, kodeUiw: 1, kodeUp3: 2, kodeUlp: 3, ulp: 4,
  username: 5, password: 6, role: 7, bidang: 8,
  tim: 9, subTim: 10, aksesMenu: 11
};

function doGet(e) {
  var p = (e && e.parameter) || {};
  var action = String(p.action || 'health').trim();
  if (action === 'health') return json_({ success: true, service: 'SiManDist API', version: '1.1.0' });
  if (action === 'cekSesi') return json_(cekSesi_(p.token));
  if (action === 'logout') return json_(logout_(p.token));
  return json_({ success: false, message: 'Action API tidak dikenal: ' + action });
}

function doPost(e) {
  try {
    var body = parseBody_(e);
    var action = String(body.action || '').trim();
    if (action === 'login') return json_(login_(body.username, body.password));
    if (action === 'cekSesi') return json_(cekSesi_(body.token));
    if (action === 'logout') return json_(logout_(body.token));
    return json_({ success: false, message: 'Action API tidak dikenal: ' + action });
  } catch (err) {
    console.error(err && err.stack ? err.stack : err);
    return json_({ success: false, message: 'Terjadi kesalahan pada server.' });
  }
}

function login_(username, password) {
  username = String(username || '').trim().toLowerCase();
  password = String(password || '');
  if (!username || !password) return { success: false, message: 'Username dan kata sandi wajib diisi.' };

  var rows = getUsersRows_();
  for (var i = 1; i < rows.length; i++) {
    var row = rows[i];
    var storedUsername = String(row[USER_COL.username] || '').trim();
    if (storedUsername.toLowerCase() !== username) continue;
    if (!constantTimeEquals_(String(row[USER_COL.password] || ''), password)) {
      return { success: false, message: 'Username atau kata sandi salah.' };
    }

    var user = userFromRow_(row);
    var token = createSession_(user);
    user.token = token;
    user.success = true;
    return user;
  }
  return { success: false, message: 'Username atau kata sandi salah.' };
}

function cekSesi_(token) {
  var session = findSession_(token);
  if (!session) return { success: false, message: 'Sesi tidak valid atau sudah berakhir.' };

  var rows = getUsersRows_();
  for (var i = 1; i < rows.length; i++) {
    if (String(rows[i][USER_COL.username] || '').trim().toLowerCase() === session.username.toLowerCase()) {
      return { success: true, sesi: userFromRow_(rows[i]) };
    }
  }
  return { success: false, message: 'Akun tidak ditemukan.' };
}

function logout_(token) {
  token = String(token || '').trim();
  if (!token) return { success: true };
  var sheet = getOrCreateSessionsSheet_();
  var hash = sha256_(token);
  var rows = sheet.getDataRange().getValues();
  for (var i = rows.length - 1; i >= 1; i--) {
    if (constantTimeEquals_(String(rows[i][1] || ''), hash)) {
      sheet.getRange(i + 1, 7).setValue('DICABUT');
      break;
    }
  }
  return { success: true };
}

function userFromRow_(row) {
  return {
    no: String(row[USER_COL.no] || ''),
    kodeUiw: String(row[USER_COL.kodeUiw] || ''),
    kodeUp3: String(row[USER_COL.kodeUp3] || ''),
    kodeUlp: String(row[USER_COL.kodeUlp] || ''),
    ulp: String(row[USER_COL.ulp] || ''),
    username: String(row[USER_COL.username] || ''),
    role: String(row[USER_COL.role] || ''),
    bidang: String(row[USER_COL.bidang] || ''),
    tim: String(row[USER_COL.tim] || ''),
    subTim: String(row[USER_COL.subTim] || ''),
    aksesMenu: String(row[USER_COL.aksesMenu] || '')
  };
}

function getUsersRows_() {
  var cache = CacheService.getScriptCache();
  var hit = cache.get('simandist_users_v1');
  if (hit) {
    try { return JSON.parse(hit); } catch (_) {}
  }
  var sheet = getSpreadsheet_().getSheetByName(CONFIG.USERS_SHEET);
  if (!sheet) throw new Error('Sheet ' + CONFIG.USERS_SHEET + ' tidak ditemukan.');
  var rows = sheet.getDataRange().getDisplayValues();
  try { cache.put('simandist_users_v1', JSON.stringify(rows), 300); } catch (_) {}
  return rows;
}

function createSession_(user) {
  var token = Utilities.getUuid() + Utilities.getUuid();
  var now = new Date();
  var expiresAt = new Date(now.getTime() + CONFIG.SESSION_DAYS * 86400000);
  var sheet = getOrCreateSessionsSheet_();
  var lock = LockService.getScriptLock();
  lock.waitLock(10000);
  try {
    sheet.appendRow([Utilities.getUuid(), sha256_(token), user.no, user.username, now, expiresAt, 'AKTIF']);
  } finally {
    lock.releaseLock();
  }
  return token;
}

function findSession_(token) {
  token = String(token || '').trim();
  if (!token) return null;
  var rows = getOrCreateSessionsSheet_().getDataRange().getValues();
  var hash = sha256_(token);
  var now = new Date();
  for (var i = rows.length - 1; i >= 1; i--) {
    if (!constantTimeEquals_(String(rows[i][1] || ''), hash)) continue;
    var expiry = rows[i][5] instanceof Date ? rows[i][5] : new Date(rows[i][5]);
    if (String(rows[i][6] || '') !== 'AKTIF' || isNaN(expiry.getTime()) || expiry <= now) return null;
    return { username: String(rows[i][3] || ''), expiresAt: expiry.toISOString() };
  }
  return null;
}

function getSpreadsheet_() {
  var id = PropertiesService.getScriptProperties().getProperty('SPREADSHEET_ID') || CONFIG.SPREADSHEET_ID;
  return SpreadsheetApp.openById(id);
}

function getOrCreateSessionsSheet_() {
  var ss = getSpreadsheet_();
  var sheet = ss.getSheetByName(CONFIG.SESSIONS_SHEET);
  if (!sheet) {
    sheet = ss.insertSheet(CONFIG.SESSIONS_SHEET);
    sheet.appendRow(['id', 'tokenHash', 'userNo', 'username', 'createdAt', 'expiresAt', 'status']);
    sheet.setFrozenRows(1);
  }
  return sheet;
}

function parseBody_(e) {
  if (!e || !e.postData || !e.postData.contents) return {};
  return JSON.parse(e.postData.contents);
}

function sha256_(value) {
  var bytes = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, String(value), Utilities.Charset.UTF_8);
  return bytes.map(function (b) { var v = b < 0 ? b + 256 : b; return ('0' + v.toString(16)).slice(-2); }).join('');
}

function constantTimeEquals_(a, b) {
  a = String(a || ''); b = String(b || '');
  var diff = a.length ^ b.length;
  var max = Math.max(a.length, b.length);
  for (var i = 0; i < max; i++) diff |= (a.charCodeAt(i) || 0) ^ (b.charCodeAt(i) || 0);
  return diff === 0;
}

function json_(payload) {
  return ContentService.createTextOutput(JSON.stringify(payload)).setMimeType(ContentService.MimeType.JSON);
}
