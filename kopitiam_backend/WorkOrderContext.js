/* Shared WO context used by Temuan download and synchronization. */
function woContext_(session, kodeWo, editable) {
  var access = woCoreAccess_(session, 'insjar');
  if (!access.success) return access;

  kodeWo = safeText_(kodeWo, 100);
  if (!kodeWo) return fail_('WO_REQUIRED', 'Kode WO wajib diisi.');

  var source = woCoreSheet_(CONFIG.WO_INSJAR_SHEET);
  var sheet = source.sheet;
  var values = sheet.getDataRange().getDisplayValues();
  if (values.length < 2) return fail_('WO_NOT_FOUND', 'WO tidak ditemukan.');

  var headers = values[0].map(function (value) {
    return String(value).trim();
  });
  var index = headerIndex_(headers);
  var codeIndex = index['kode wo'];
  var ulpCodeIndex = index['kode ulp'];
  var ulpIndex = index['ulp'];
  var statusIndex = index['status wo'];
  if (codeIndex === undefined || ulpCodeIndex === undefined) {
    return fail_('WO_HEADERS_INVALID', 'Header Kode WO atau Kode ULP tidak ditemukan.');
  }

  for (var row = 1; row < values.length; row++) {
    if (String(values[row][codeIndex] || '').trim() !== kodeWo) continue;
    var codeMatches = normalizeCode_(values[row][ulpCodeIndex]) === access.kodeUlp;
    var nameMatches = ulpIndex !== undefined && access.ulp &&
      normalize_(values[row][ulpIndex]) === access.ulp;
    if (!codeMatches && !nameMatches) {
      return fail_('WO_OWNERSHIP_DENIED', 'WO bukan milik ULP akun ini.');
    }
    var status = statusIndex === undefined ? '' : normalize_(values[row][statusIndex]);
    if (editable && status === 'selesai') {
      return fail_('WO_LOCKED', 'WO sudah selesai dan hanya dapat dilihat.');
    }
    return {
      success: true,
      sheet: sheet,
      headers: headers,
      index: index,
      row: values[row],
      rowNumber: row + 1,
      status: status,
      kodeUlp: access.kodeUlp,
    };
  }
  return fail_('WO_NOT_FOUND', 'WO tidak ditemukan.');
}

function getTemuanInspeksi_(token, kodeWo) {
  var auth = cekSesi_(token);
  if (!auth.success) return auth;
  var context = woContext_(auth.sesi, kodeWo, false);
  if (!context.success) return context;

  var sheet = temuanSheet_();
  var values = sheet.getDataRange().getDisplayValues();
  if (values.length < 2) return { success: true, total: 0, rows: [] };
  var headers = values[0].map(function (value) {
    return String(value).trim();
  });
  var index = headerIndex_(headers);
  if (index['kode wo'] === undefined || index['kode ulp'] === undefined) {
    return fail_('SHEET_HEADERS_INVALID', 'Header Inp_Temuan belum valid.');
  }

  var rows = [];
  for (var row = 1; row < values.length; row++) {
    if (String(values[row][index['kode wo']] || '').trim() !== String(kodeWo).trim()) continue;
    if (normalizeCode_(values[row][index['kode ulp']]) !== context.kodeUlp) continue;
    rows.push(rowObject_(headers, values[row]));
  }
  return { success: true, total: rows.length, rows: rows };
}
