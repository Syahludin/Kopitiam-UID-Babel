'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const root = path.resolve(__dirname, '..');
const code = fs.readFileSync(path.join(root, 'Code.js'), 'utf8');
const manifest = JSON.parse(
  fs.readFileSync(path.join(root, 'appsscript.json'), 'utf8'),
);

function loadBackend() {
  const sandbox = {
    console,
    Utilities: {
      Charset: {UTF_8: 'utf8'},
      DigestAlgorithm: {SHA_256: 'sha256'},
      computeDigest(_algorithm, value) {
        return [...crypto.createHash('sha256').update(String(value)).digest()]
          .map((byte) => (byte > 127 ? byte - 256 : byte));
      },
    },
  };
  vm.createContext(sandbox);
  vm.runInContext(code, sandbox, {filename: 'Code.js'});
  return sandbox;
}

test('Apps Script source parses and exposes only health over GET', () => {
  assert.match(code, /function doGet\(e\)/);
  assert.match(code, /POST_REQUIRED/);
  assert.doesNotMatch(code, /e\.parameter\.(?:token|password|username)/);
});

test('anonymous deployment executes as owner and routes protected work through POST', () => {
  assert.equal(manifest.webapp.executeAs, 'USER_DEPLOYING');
  assert.equal(manifest.webapp.access, 'ANYONE_ANONYMOUS');
  for (const action of [
    'getMasterData',
    'getWoInsjar',
    'syncWoInsjar',
    'getTemuanInspeksi',
    'syncTemuanInspeksi',
  ]) {
    assert.match(code, new RegExp("a==='" + action + "'"));
  }
});

test('authorization and ownership guards remain present', () => {
  assert.match(code, /WO_ACCESS_DENIED/);
  assert.match(code, /WO_OWNERSHIP_DENIED/);
  assert.match(code, /WO_LOCKED/);
  assert.match(code, /OBJECT_MISMATCH/);
  assert.match(code, /cekSesi_\(t\)/);
});

test('master-data response explicitly strips password', () => {
  assert.match(
    code,
    /n===CONFIG\.USERS_SHEET&&normalize_\(k\)==='password'\)continue/,
  );
});

test('payload and image limits remain enforced', () => {
  assert.match(code, /MAX_IMAGE_BYTES:5\*1024\*1024/);
  assert.match(code, /rows\.length>100/);
  assert.match(code, /e\.postData\.contents\.length>15\*1024\*1024/);
  assert.match(code, /bytes\.length>CONFIG\.MAX_IMAGE_BYTES/);
});

test('pure validators reject traversal, negative numbers, and oversized bodies', () => {
  const backend = loadBackend();
  assert.throws(() => backend.safePath_('..'), /Invalid path/);
  assert.throws(() => backend.safePath_('.'), /Invalid path/);
  assert.throws(() => backend.numericOrBlank_('-1'), /Invalid numeric value/);
  assert.equal(backend.numericOrBlank_('1,25'), 1.25);
  assert.throws(
    () => backend.parseBody_({postData: {contents: 'x'.repeat(15 * 1024 * 1024 + 1)}}),
    /Payload too large/,
  );
});

test('constant-time comparison and code normalization behave predictably', () => {
  const backend = loadBackend();
  assert.equal(backend.constantTimeEqual_('secret', 'secret'), true);
  assert.equal(backend.constantTimeEqual_('secret', 'Secret'), false);
  assert.equal(backend.constantTimeEqual_('short', 'longer'), false);
  assert.equal(backend.normalizeCode_(' 001-abc '), '1ABC');
});
