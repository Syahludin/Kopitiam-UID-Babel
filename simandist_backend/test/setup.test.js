'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(
  path.resolve(__dirname, '..', 'Setup.js'),
  'utf8',
);

function loadSetup(records = {}, now = Date.now()) {
  const properties = new Map(Object.entries(records));
  let locks = 0;
  let unlocks = 0;
  const sandbox = {
    console,
    Date: class extends Date {
      static now() { return now; }
    },
    Object,
    PropertiesService: {
      getScriptProperties: () => ({
        getProperties: () => Object.fromEntries(properties),
        getProperty: (key) => properties.get(key) || null,
        setProperty: (key, value) => properties.set(key, String(value)),
        deleteProperty: (key) => properties.delete(key),
      }),
    },
    LockService: {
      getScriptLock: () => ({
        waitLock() { locks++; },
        releaseLock() { unlocks++; },
      }),
    },
  };
  vm.createContext(sandbox);
  vm.runInContext(source, sandbox, {filename: 'Setup.js'});
  return {backend: sandbox, properties, lockCounts: () => [locks, unlocks]};
}

test('setup matches the active backend schema and avoids legacy session APIs', () => {
  assert.match(source, /CONFIG\.SPREADSHEET_ID/);
  assert.match(source, /CONFIG\.WO_SPREADSHEET_ID/);
  assert.match(source, /CONFIG\.TEMUAN_SPREADSHEET_ID/);
  assert.match(source, /'Kode UIW'[\s\S]*'Akses Menu'/);
  assert.doesNotMatch(source, /CONFIG\.SESSIONS_SHEET/);
  assert.doesNotMatch(source, /hashPassword_|getSheet_/);
});

test('device policy is 30 days absolute and 7 days idle', () => {
  assert.match(source, /DEVICE_TOKEN_MAX_AGE_MS = 30 \* 24 \* 60 \* 60 \* 1000/);
  assert.match(source, /DEVICE_TOKEN_IDLE_MS = 7 \* 24 \* 60 \* 60 \* 1000/);
  assert.match(source, /everyHours\(1\)/);
});

test('server cleanup removes expired, idle, future, and corrupt device tokens', () => {
  const day = 24 * 60 * 60 * 1000;
  const now = Date.UTC(2026, 7, 28, 3, 0, 0);
  const records = {
    PASSWORD_PEPPER: 'keep-me',
    device_active: JSON.stringify({createdAt: now - day, lastUsedAt: now - 1000}),
    device_expired: JSON.stringify({createdAt: now - 30 * day, lastUsedAt: now - 1000}),
    device_idle: JSON.stringify({createdAt: now - 8 * day, lastUsedAt: now - 7 * day}),
    device_future: JSON.stringify({createdAt: now + day, lastUsedAt: now + day}),
    device_corrupt: '{bad-json',
  };
  const {backend, properties, lockCounts} = loadSetup(records, now);
  const result = backend.bersihkanTokenPerangkatKedaluwarsa();
  assert.equal(result.success, true);
  assert.equal(result.dihapus, 4);
  assert.equal(result.aktif, 1);
  assert.ok(properties.has('device_active'));
  assert.ok(properties.has('PASSWORD_PEPPER'));
  assert.equal(properties.has('device_expired'), false);
  assert.equal(properties.has('device_idle'), false);
  assert.equal(properties.has('device_future'), false);
  assert.equal(properties.has('device_corrupt'), false);
  assert.deepEqual(lockCounts(), [1, 1]);
});

test('cleanup ignores unrelated Script Properties', () => {
  const now = Date.UTC(2026, 7, 28, 3, 0, 0);
  const {backend, properties} = loadSetup({OTHER_CONFIG: 'value'}, now);
  const result = backend.bersihkanTokenPerangkatKedaluwarsa();
  assert.equal(result.dihapus, 0);
  assert.equal(properties.get('OTHER_CONFIG'), 'value');
});
