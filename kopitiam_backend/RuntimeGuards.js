var ACTION_LIMITS_ = {
  cekPerangkat: {limit: 20, seconds: 60},
  getMasterData: {limit: 10, seconds: 60},
  getWoInsjar: {limit: 20, seconds: 60},
  getTemuanInspeksi: {limit: 30, seconds: 60},
  syncWoInsjar: {limit: 10, seconds: 60},
  syncTemuanInspeksi: {limit: 6, seconds: 60}
};

function validateDeviceRecord_(record, now) {
  now = Number(now || Date.now());
  if (!record || typeof record !== 'object') return 'DEVICE_CORRUPT';
  var createdAt = Number(record.createdAt || 0);
  var lastUsedAt = Number(record.lastUsedAt || createdAt || 0);
  if (!createdAt || !lastUsedAt || createdAt > now || lastUsedAt > now) {
    return 'DEVICE_TIME_INVALID';
  }
  if (now - createdAt >= 7 * 24 * 60 * 60 * 1000) {
    return 'DEVICE_MAX_AGE';
  }
  if (now - lastUsedAt >= 1 * 24 * 60 * 60 * 1000) {
    return 'DEVICE_IDLE_EXPIRED';
  }
  return '';
}

function consumeActionQuota_(action, identity) {
  var policy = ACTION_LIMITS_[String(action || '')];
  if (!policy) return {success: true};
  var subject = sha256_(String(identity || 'anonymous')).substring(0, 24);
  var key = 'quota_' + action + '_' + subject;
  var cache = CacheService.getScriptCache();
  var count = Number(cache.get(key) || 0) + 1;
  cache.put(key, String(count), policy.seconds);
  return count > policy.limit
    ? fail_('ACTION_RATE_LIMIT', 'Terlalu banyak permintaan. Coba lagi sebentar.')
    : {success: true};
}

function accountStatus_(username) {
  var sheet = getSpreadsheet_().getSheetByName(CONFIG.USERS_SHEET);
  if (!sheet) throw new Error('User sheet missing');
  var values = sheet.getDataRange().getDisplayValues();
  if (!values.length) return {exists: false, active: false};
  var index = headerIndex_(values[0]);
  var usernameIndex = index.username;
  var statusIndex = index.status;
  for (var row = 1; row < values.length; row++) {
    if (normalize_(values[row][usernameIndex]) !== normalize_(username)) continue;
    if (statusIndex === undefined) return {exists: true, active: true};
    var status = normalize_(values[row][statusIndex]);
    return {
      exists: true,
      active: ['aktif', 'active', '1', 'true'].indexOf(status) >= 0
    };
  }
  return {exists: false, active: false};
}

function validateFindingMaster_(object, tier, finding, priority) {
  var sheet = getSpreadsheet_().getSheetByName('List_Temuan');
  if (!sheet) return fail_('MASTER_SHEET_MISSING', 'Master temuan tidak tersedia.');
  var values = sheet.getDataRange().getDisplayValues();
  if (values.length < 2) return fail_('MASTER_EMPTY', 'Master temuan kosong.');
  var index = headerIndex_(values[0]);
  var findingIndex = index.temuan !== undefined ? index.temuan : index['nama temuan'];
  var objectIndex = index['objek inspeksi'] !== undefined
    ? index['objek inspeksi'] : index['jenis object'];
  var tierIndex = index.tier;
  var priorityIndex = index.prioritas;
  if (findingIndex === undefined || tierIndex === undefined) {
    return fail_('MASTER_HEADERS_INVALID', 'Header master temuan belum valid.');
  }
  for (var row = 1; row < values.length; row++) {
    var rowFinding = String(values[row][findingIndex] || '').trim();
    var rowTier = String(values[row][tierIndex] || '').trim();
    var rowObject = objectIndex === undefined ? ''
      : String(values[row][objectIndex] || '').trim();
    if (normalize_(rowFinding) !== normalize_(finding) ||
        normalize_(rowTier) !== normalize_(tier) ||
        (rowObject && normalize_(rowObject).indexOf(normalize_(object)) < 0)) continue;
    var expectedPriority = priorityIndex === undefined ? ''
      : String(values[row][priorityIndex] || '').trim();
    if (expectedPriority && normalize_(expectedPriority) !== normalize_(priority)) {
      return fail_('PRIORITY_MISMATCH', 'Prioritas tidak sesuai master.');
    }
    return {success: true};
  }
  return fail_('FINDING_MASTER_INVALID', 'Kombinasi Object, Tier, dan Temuan tidak terdaftar.');
}
