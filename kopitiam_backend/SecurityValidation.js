var MIN_JPEG_BYTES = 1024;

/** Mengurai dan memvalidasi koordinat sebelum dipakai backend. */
function validateCoordinate_(value) {
  var text = String(value == null ? '' : value).trim();
  if (!/^-?\d+(?:\.\d+)?\s*,\s*-?\d+(?:\.\d+)?$/.test(text)) {
    throw new Error('Invalid coordinate format');
  }
  var parts = text.split(',');
  var latitude = Number(parts[0].trim());
  var longitude = Number(parts[1].trim());
  if (!isFinite(latitude) || !isFinite(longitude) ||
      latitude < -90 || latitude > 90 ||
      longitude < -180 || longitude > 180) {
    throw new Error('Coordinate out of range');
  }
  if (latitude === 0 && longitude === 0) {
    throw new Error('Null Island coordinate rejected');
  }
  return {latitude: latitude, longitude: longitude};
}

/** Memastikan byte benar-benar JPEG, bukan file palsu berlabel image/jpeg. */
function validateJpegBytes_(bytes) {
  if (!bytes || typeof bytes.length !== 'number') {
    throw new Error('Invalid image bytes');
  }
  if (bytes.length < MIN_JPEG_BYTES) {
    throw new Error('JPEG too small');
  }
  function unsigned_(value) {
    value = Number(value);
    return value < 0 ? value + 256 : value;
  }
  var last = bytes.length - 1;
  var hasStart = unsigned_(bytes[0]) === 0xFF &&
    unsigned_(bytes[1]) === 0xD8 &&
    unsigned_(bytes[2]) === 0xFF;
  var hasEnd = unsigned_(bytes[last - 1]) === 0xFF &&
    unsigned_(bytes[last]) === 0xD9;
  if (!hasStart || !hasEnd) {
    throw new Error('Invalid JPEG signature');
  }
  return true;
}
