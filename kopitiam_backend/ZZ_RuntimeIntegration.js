/*
 * Integrasi terakhir untuk handler produksi. Prefix ZZ memastikan bootstrap
 * dievaluasi setelah modul fungsi utama saat dipush melalui clasp.
 */
var _unguardedDoPost_ = doPost;
var _unguardedCekPerangkat_ = cekPerangkat_;
var _unguardedCekSesi_ = cekSesi_;
var _unguardedSyncTemuan_ = syncTemuanInspeksiIdempotent_;

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

doPost = function (e) {
  try {
    var body = parseBody_(e);
    var action = String(body.action || "").trim();
    var quota = consumeActionQuota_(action, runtimeIdentity_(body));
    if (!quota.success) return json_(quota);
  } catch (_) {
    // Parser dan respons error resmi tetap ditangani oleh router utama.
  }
  return _unguardedDoPost_(e);
};

cekPerangkat_ = function (token) {
  token = String(token || "").trim();
  if (!/^[a-f0-9]{64}$/i.test(token)) {
    return fail_("DEVICE_INVALID", "Sesi perangkat tidak valid.");
  }
  var props = PropertiesService.getScriptProperties();
  var key = "device_" + token;
  var raw = props.getProperty(key);
  if (!raw) {
    return fail_(
      "DEVICE_UNKNOWN",
      "Sesi perangkat tidak dikenali. Silakan login ulang.",
    );
  }
  var record;
  try {
    record = JSON.parse(raw);
  } catch (_) {
    props.deleteProperty(key);
    return fail_(
      "DEVICE_CORRUPT",
      "Sesi perangkat rusak. Silakan login ulang.",
    );
  }
  var expiry = validateDeviceRecord_(record, Date.now());
  if (expiry) {
    props.deleteProperty(key);
    return fail_(expiry, "Sesi perangkat sudah berakhir. Silakan login ulang.");
  }
  var account = accountStatus_(record.username);
  if (!account.exists || !account.active) {
    props.deleteProperty(key);
    return fail_("ACCOUNT_INACTIVE", "Akun tidak aktif atau tidak ditemukan.");
  }
  return _unguardedCekPerangkat_(token);
};

cekSesi_ = function (token) {
  var result = _unguardedCekSesi_(token);
  if (!result.success) return result;
  var binding = verifySessionDeviceBinding_(token, result.sesi);
  if (!binding.success) return binding;
  return result;
};

syncTemuanInspeksiIdempotent_ = function (token, incoming) {
  if (!incoming || typeof incoming !== "object") {
    return fail_("FINDING_REQUIRED", "Data temuan kosong.");
  }
  var master = validateFindingMaster_(
    safeText_(incoming["Jenis Object"], 40),
    safeText_(incoming["Tier"], 20),
    safeText_(incoming["Temuan"], 200),
    safeText_(incoming["Prioritas"], 20),
  );
  if (!master.success) return master;
  return _unguardedSyncTemuan_(token, incoming);
};
