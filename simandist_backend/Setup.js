function setupBackend() {
  var props = PropertiesService.getScriptProperties();
  var spreadsheetId = props.getProperty('SPREADSHEET_ID');
  if (!spreadsheetId) throw new Error('Isi SPREADSHEET_ID di Script Properties terlebih dahulu.');
  if (!props.getProperty('PASSWORD_PEPPER')) {
    props.setProperty('PASSWORD_PEPPER', Utilities.getUuid() + Utilities.getUuid());
  }

  var ss = SpreadsheetApp.openById(spreadsheetId);
  ensureSheet_(ss, CONFIG.USERS_SHEET, [
    'id', 'email', 'username', 'passwordHash', 'salt', 'role', 'unit', 'bidang', 'status', 'createdAt', 'updatedAt'
  ]);
  ensureSheet_(ss, CONFIG.SESSIONS_SHEET, [
    'id', 'tokenHash', 'userId', 'username', 'createdAt', 'expiresAt', 'status'
  ]);
  return 'Backend SiManDist siap.';
}

function buatUserPertama(username, password, email) {
  username = String(username || '').trim();
  password = String(password || '');
  if (!username || password.length < 8) throw new Error('Username wajib diisi dan password minimal 8 karakter.');

  var sheet = getSheet_(CONFIG.USERS_SHEET);
  var values = sheet.getDataRange().getValues();
  for (var i = 1; i < values.length; i++) {
    if (String(values[i][2] || '').toLowerCase() === username.toLowerCase()) {
      throw new Error('Username sudah tersedia.');
    }
  }

  var salt = Utilities.getUuid();
  var now = new Date();
  sheet.appendRow([
    Utilities.getUuid(), String(email || '').trim(), username,
    hashPassword_(password, salt), salt, 'Admin', 'PLN UID Babel',
    'Distribusi', 'AKTIF', now, now
  ]);
  return 'User ' + username + ' berhasil dibuat.';
}

function bersihkanSesiKedaluwarsa() {
  var sheet = getSheet_(CONFIG.SESSIONS_SHEET);
  var values = sheet.getDataRange().getValues();
  var now = new Date();
  for (var i = values.length - 1; i >= 1; i--) {
    var expiresAt = values[i][5] instanceof Date ? values[i][5] : new Date(values[i][5]);
    if (String(values[i][6] || '') !== 'AKTIF' || (expiresAt && expiresAt <= now)) sheet.deleteRow(i + 1);
  }
}

function ensureSheet_(ss, name, headers) {
  var sheet = ss.getSheetByName(name) || ss.insertSheet(name);
  if (sheet.getLastRow() === 0) {
    sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
    sheet.setFrozenRows(1);
    sheet.getRange(1, 1, 1, headers.length).setFontWeight('bold');
  }
  return sheet;
}
