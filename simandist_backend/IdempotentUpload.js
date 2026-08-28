function preparePhoto_(base64Value, role) {
  if (!base64Value) throw new Error(role + ' required');
  var encoded = String(base64Value);
  if (encoded.length > Math.ceil(CONFIG.MAX_IMAGE_BYTES * 4 / 3) + 16) {
    throw new Error(role + ' too large');
  }
  var bytes;
  try {
    bytes = Utilities.base64Decode(encoded);
  } catch (_) {
    throw new Error(role + ' invalid base64');
  }
  if (bytes.length > CONFIG.MAX_IMAGE_BYTES) {
    throw new Error(role + ' too large');
  }
  validateJpegBytes_(bytes);
  return {
    role: role,
    bytes: bytes,
    digest: digestBytes_(bytes)
  };
}

function digestBytes_(bytes) {
  return Utilities.computeDigest(
    Utilities.DigestAlgorithm.SHA_256,
    bytes
  ).map(function(value) {
    var byte = value < 0 ? value + 256 : value;
    return ('0' + byte.toString(16)).slice(-2);
  }).join('');
}

function putPhotoIdempotent_(folder, code, prepared) {
  var filename = safePath_(
    code + '.' + prepared.role + '.' + prepared.digest.substring(0, 24) + '.jpg'
  );
  var matches = folder.getFilesByName(filename);
  if (matches.hasNext()) {
    var existing = matches.next();
    return {
      file: existing,
      name: existing.getName(),
      url: existing.getUrl(),
      digest: prepared.digest,
      created: false
    };
  }
  var created = folder.createFile(
    Utilities.newBlob(prepared.bytes, 'image/jpeg', filename)
  );
  return {
    file: created,
    name: created.getName(),
    url: created.getUrl(),
    digest: prepared.digest,
    created: true
  };
}

function rollbackCreatedPhotos_(photos) {
  (photos || []).forEach(function(photo) {
    if (!photo || !photo.created || !photo.file) return;
    try {
      photo.file.setTrashed(true);
    } catch (_) {}
  });
}

function removeStalePhotos_(folder, code, keepNames) {
  var prefix = code + '.';
  var files = folder.getFiles();
  while (files.hasNext()) {
    var file = files.next();
    var name = file.getName();
    if (name.indexOf(prefix) !== 0 || keepNames.indexOf(name) >= 0) continue;
    if (name.indexOf('.Foto Temuan.') < 0 &&
        name.indexOf('.Foto Lingkungan.') < 0) continue;
    try {
      file.setTrashed(true);
    } catch (_) {}
  }
}

function photoIdempotencyKey_(code, primary, environment) {
  return sha256_(
    code + '|' + primary.digest + '|' + environment.digest
  ).substring(0, 40);
}
