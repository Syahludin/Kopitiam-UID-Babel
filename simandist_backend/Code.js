var CONFIG = {
  USERS_SHEET: 'db_Users',
  SESSIONS_SHEET: 'db_Sessions',
  SESSION_DAYS: 30,
  HASH_ROUNDS: 8000
};

function doGet(e) {
  var action = String((e && e.parameter && e.parameter.action) || 'health');
  if (action === 'health') {
    return json_({ success: true, service: 'SiManDist API', version: '1.0.0' });
  }
  return json_({ success: false, message: 'Gunakan POST JSON untuk API SiManDist.' });
}

function doPost(e) {
  try {
    var body = parseBody_(e);
    var action = String(body.action || '').trim();
    var result;

    switch (action) {
      case 'login':
        result = login_(body.username, body.password);
        break;
      case 'cekSesi':
        result = cekSesi_(body.token);
        break;
      case 'logout':
        result = logout_(body.token);
        break;
      default:
        result = { success: false, message: 'Action API tidak dikenal: ' + action };
    }
    return json_(result);
  } catch (err) {
    console.error(err && err.stack ? err.stack : err);
    return json_({ success: false, message: 'Terjadi kesalahan pada server.' });
  }
}

function login_(username, password) {
  username = String(username || '').trim().toLowerCase();
  password = String(password || '');
  if (!username || !password) {
    return { success: false, message: 'Username dan kata sandi wajib diisi.' };
  }

  var sheet = getSheet_(CONFIG.USERS_SHEET);
  var values = sheet.getDataRange().getValues();
  for (var i = 1; i < values.length; i++) {
    var row = values[i];
    var storedUsername = String(row[2] || '').trim();
    if (storedUsername.toLowerCase() !== username) continue;
    if (String(row[8] || '').toUpperCase() !== 'AKTIF') {
      return { success: false, message: 'Akun tidak aktif.' };
    }

    var expectedHash = String(row[3] || '');
    var salt = String(row[4] || '');
    if (!constantTimeEquals_(hashPassword_(password, salt), expectedHash)) {
      return { success: false, message: 'Username atau kata sandi salah.' };
    }

    var token = createSession_(row);
    return {
      success: true,
      token: token,
      username: storedUsername,
      email: String(row[1] || ''),
      role: String(row[5] || ''),
      unit: String(row[6] || 'PLN UID Babel'),
      bidang: String(row[7] || '')
    };
  }
  return { success: false, message: 'Username atau kata sandi salah.' };
}

function cekSesi_(token) {
  var session = findSession_(token);
  if (!session) return { success: false, message: 'Sesi tidak valid atau sudah berakhir.' };
  return { success: true, sesi: session };
}

function logout_(token) {
  token = String(token || '').trim();
  if (!token) return { success: true };
  var sheet = getSheet_(CONFIG.SESSIONS_SHEET);
  var tokenHash = sha256_(token);
  var values = sheet.getDataRange().getValues();
  for (var i = values.length - 1; i >= 1; i--) {
    if (constantTimeEquals_(String(values[i][1] || ''), tokenHash)) {
      sheet.getRange(i + 1, 7).setValue('DICABUT');
      break;
    }
  }
  return { success: true };
}

function createSession_(userRow) {
  var token = Utilities.getUuid() + Utilities.getUuid();
  var now = new Date();
  var expiresAt = new Date(now.getTime() + CONFIG.SESSION_DAYS * 86400000);
  var sheet = getSheet_(CONFIG.SESSIONS_SHEET);
  var lock = LockService.getScriptLock();
  lock.waitLock(10000);
  try {
    sheet.appendRow([
      Utilities.getUuid(), sha256_(token), String(userRow[0] || ''),
      String(userRow[2] || ''), now, expiresAt, 'AKTIF'
    ]);
  } finally {
    lock.releaseLock();
  }
  return token;
}

function findSession_(token) {
  token = String(token || '').trim();
  if (!token) return null;
  var tokenHash = sha256_(token);
  var sheet = getSheet_(CONFIG.SESSIONS_SHEET);
  var values = sheet.getDataRange().getValues();
  var now = new Date();
  for (var i = values.length - 1; i >= 1; i--) {
    var row = values[i];
    if (!constantTimeEquals_(String(row[1] || ''), tokenHash)) continue;
    var expiresAt = row[5] instanceof Date ? row[5] : new Date(row[5]);
    if (String(row[6] || '') !== 'AKTIF' || isNaN(expiresAt.getTime()) || expiresAt <= now) return null;
    return {
      userId: String(row[2] || ''),
      username: String(row[3] || ''),
      expiresAt: expiresAt.toISOString()
    };
  }
  return null;
}

function parseBody_(e) {
  if (!e || !e.postData || !e.postData.contents) return {};
  try { return JSON.parse(e.postData.contents); }
  catch (_) { throw new Error('Body harus berupa JSON yang valid.'); }
}

function getSpreadsheet_() {
  var id = PropertiesService.getScriptProperties().getProperty('SPREADSHEET_ID');
  if (!id) throw new Error('SPREADSHEET_ID belum diatur di Script Properties.');
  return SpreadsheetApp.openById(id);
}

function getSheet_(name) {
  var sheet = getSpreadsheet_().getSheetByName(name);
  if (!sheet) throw new Error('Sheet tidak ditemukan: ' + name);
  return sheet;
}

function hashPassword_(password, salt) {
  var pepper = PropertiesService.getScriptProperties().getProperty('PASSWORD_PEPPER');
  if (!pepper) throw new Error('PASSWORD_PEPPER belum diatur.');
  var value = String(password) + ':' + String(salt) + ':' + pepper;
  for (var i = 0; i < CONFIG.HASH_ROUNDS; i++) value = sha256_(value);
  return value;
}

function sha256_(value) {
  var bytes = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, String(value), Utilities.Charset.UTF_8);
  return bytes.map(function(b) { var v = b < 0 ? b + 256 : b; return ('0' + v.toString(16)).slice(-2); }).join('');
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
