'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const root = path.resolve(__dirname, '..');
const helperSource = fs.readFileSync(path.join(root, 'IdempotentUpload.js'), 'utf8');
const production = fs.readFileSync(path.join(root, 'Code.js'), 'utf8');

function fakeFolder() {
  const files = [];
  function iterator(values) {
    let index = 0;
    return {hasNext: () => index < values.length, next: () => values[index++]};
  }
  return {
    files,
    getFilesByName(name) { return iterator(files.filter((file) => file.name === name && !file.trashed)); },
    getFiles() { return iterator(files.filter((file) => !file.trashed)); },
    createFile(blob) {
      const file = {
        name: blob.name,
        trashed: false,
        getName() { return this.name; },
        getUrl() { return `drive://${this.name}`; },
        setTrashed(value) { this.trashed = value; },
      };
      files.push(file);
      return file;
    },
  };
}

function backend() {
  const sandbox = {
    CONFIG: {MAX_IMAGE_BYTES: 5 * 1024 * 1024},
    validateJpegBytes_(bytes) {
      if (bytes[0] !== 0xff || bytes.at(-1) !== 0xd9) throw new Error('bad jpeg');
    },
    safePath_: (value) => value,
    sha256_: (value) => crypto.createHash('sha256').update(value).digest('hex'),
    Utilities: {
      DigestAlgorithm: {SHA_256: 'sha256'},
      base64Decode: (value) => [...Buffer.from(value, 'base64')],
      computeDigest: (_algorithm, bytes) => [...crypto.createHash('sha256').update(Buffer.from(bytes)).digest()]
        .map((value) => value > 127 ? value - 256 : value),
      newBlob: (bytes, mime, name) => ({bytes, mime, name}),
    },
  };
  vm.createContext(sandbox);
  vm.runInContext(helperSource, sandbox, {filename: 'IdempotentUpload.js'});
  return sandbox;
}

test('same finding and bytes reuse the exact same Drive file', () => {
  const api = backend();
  const folder = fakeFolder();
  const photo = {role: 'Foto Temuan', bytes: [0xff, 1, 2, 0xd9], digest: 'a'.repeat(64)};
  const first = api.putPhotoIdempotent_(folder, 'WO.TO-001', photo);
  const retry = api.putPhotoIdempotent_(folder, 'WO.TO-001', photo);
  assert.equal(first.created, true);
  assert.equal(retry.created, false);
  assert.equal(first.name, retry.name);
  assert.equal(folder.files.length, 1);
});

test('different content gets a different deterministic filename', () => {
  const api = backend();
  const folder = fakeFolder();
  const first = api.putPhotoIdempotent_(folder, 'WO.TO-001', {role: 'Foto Temuan', bytes: [], digest: 'a'.repeat(64)});
  const changed = api.putPhotoIdempotent_(folder, 'WO.TO-001', {role: 'Foto Temuan', bytes: [], digest: 'b'.repeat(64)});
  assert.notEqual(first.name, changed.name);
  assert.equal(folder.files.length, 2);
});

test('rollback trashes only files created by the failed request', () => {
  const api = backend();
  const folder = fakeFolder();
  const existing = api.putPhotoIdempotent_(folder, 'WO.TO-001', {role: 'Foto Temuan', bytes: [], digest: 'a'.repeat(64)});
  const reused = api.putPhotoIdempotent_(folder, 'WO.TO-001', {role: 'Foto Temuan', bytes: [], digest: 'a'.repeat(64)});
  const created = api.putPhotoIdempotent_(folder, 'WO.TO-001', {role: 'Foto Lingkungan', bytes: [], digest: 'b'.repeat(64)});
  api.rollbackCreatedPhotos_([reused, created]);
  assert.equal(existing.file.trashed, false);
  assert.equal(created.file.trashed, true);
});

test('production flow must validate both photos before creating Drive files and use a lock', () => {
  assert.match(production, /preparePhoto_\(incoming\.fotoTemuanBase64/);
  assert.match(production, /preparePhoto_\(incoming\.fotoLingkunganBase64/);
  assert.match(production, /putPhotoIdempotent_/);
  assert.match(production, /photoIdempotencyKey_/);
  assert.match(production, /rollbackCreatedPhotos_/);
  assert.match(production, /removeStalePhotos_/);
  assert.match(production, /LockService\.getScriptLock\(\)/);
});
