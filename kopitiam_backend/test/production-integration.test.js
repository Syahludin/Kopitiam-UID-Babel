'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const integration = fs.readFileSync(
  path.join(root, 'ZZ_RuntimeIntegration.js'),
  'utf8',
);

function expectBefore(first, second) {
  const left = integration.indexOf(first);
  const right = integration.indexOf(second);
  assert.ok(left >= 0, `${first} tidak ditemukan`);
  assert.ok(right >= 0, `${second} tidak ditemukan`);
  assert.ok(left < right, `${first} harus dijalankan sebelum ${second}`);
}

test('production POST router consumes action quota before dispatch', () => {
  assert.match(integration, /doPost = function\(e\)/);
  expectBefore('consumeActionQuota_', '_unguardedDoPost_(e)');
  assert.match(integration, /runtimeIdentity_\(body\)/);
});

test('device handler fails closed before issuing a fresh session', () => {
  assert.match(integration, /cekPerangkat_ = function\(token\)/);
  expectBefore('validateDeviceRecord_', '_unguardedCekPerangkat_(token)');
  expectBefore('accountStatus_', '_unguardedCekPerangkat_(token)');
  assert.match(integration, /props\.deleteProperty\(key\)/);
  assert.match(integration, /ACCOUNT_INACTIVE/);
});

test('cached sessions are revoked when account becomes inactive', () => {
  assert.match(integration, /cekSesi_ = function\(token\)/);
  assert.match(integration, /remove\('session_'/);
  assert.match(integration, /accountStatus_\(result\.sesi\.username\)/);
});

test('master validation runs before idempotent Temuan transaction', () => {
  assert.match(integration, /syncTemuanInspeksiIdempotent_ = function/);
  expectBefore('validateFindingMaster_', '_unguardedSyncTemuan_(token, incoming)');
  assert.match(integration, /incoming\['Jenis Object'\]/);
  assert.match(integration, /incoming\['Prioritas'\]/);
});
