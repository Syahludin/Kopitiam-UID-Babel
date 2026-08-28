'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(
  path.resolve(__dirname, '..', 'SecurityValidation.js'),
  'utf8',
);

function validators() {
  const sandbox = {Number, String, isFinite};
  vm.createContext(sandbox);
  vm.runInContext(source, sandbox, {filename: 'SecurityValidation.js'});
  return sandbox;
}

function jpegBytes(size = 2048) {
  const bytes = new Array(size).fill(0x11);
  bytes[0] = 0xFF;
  bytes[1] = 0xD8;
  bytes[2] = 0xFF;
  bytes[size - 2] = 0xFF;
  bytes[size - 1] = 0xD9;
  return bytes;
}

test('accepts a real-looking JPEG signature and valid Babel coordinate', () => {
  const backend = validators();
  assert.equal(backend.validateJpegBytes_(jpegBytes()), true);
  const point = backend.validateCoordinate_('-3.019482, 106.454827');
  assert.equal(point.latitude, -3.019482);
  assert.equal(point.longitude, 106.454827);
});

test('rejects executable, PDF, PNG, ZIP, and HTML payloads disguised as JPEG', () => {
  const backend = validators();
  const attacks = [
    [0x4D, 0x5A],
    [0x25, 0x50, 0x44, 0x46],
    [0x89, 0x50, 0x4E, 0x47],
    [0x50, 0x4B, 0x03, 0x04],
    [0x3C, 0x68, 0x74, 0x6D, 0x6C],
  ];
  for (const signature of attacks) {
    const bytes = new Array(2048).fill(0x11);
    signature.forEach((value, index) => { bytes[index] = value; });
    bytes[2046] = 0xFF;
    bytes[2047] = 0xD9;
    assert.throws(() => backend.validateJpegBytes_(bytes), /JPEG signature/);
  }
});

test('rejects truncated JPEG and fake header-only JPEG', () => {
  const backend = validators();
  const truncated = jpegBytes();
  truncated[truncated.length - 2] = 0x00;
  truncated[truncated.length - 1] = 0x00;
  assert.throws(() => backend.validateJpegBytes_(truncated), /JPEG signature/);
  assert.throws(
    () => backend.validateJpegBytes_([0xFF, 0xD8, 0xFF, 0xFF, 0xD9]),
    /too small/,
  );
});

test('supports signed bytes returned by Apps Script base64Decode', () => {
  const backend = validators();
  const bytes = jpegBytes().map((value) => value > 127 ? value - 256 : value);
  assert.equal(backend.validateJpegBytes_(bytes), true);
});

test('rejects latitude and longitude outside world bounds', () => {
  const backend = validators();
  for (const value of [
    '90.0001, 106', '-90.0001, 106', '-3, 180.0001', '-3, -180.0001',
  ]) {
    assert.throws(() => backend.validateCoordinate_(value), /out of range/);
  }
});

test('rejects Null Island, NaN, Infinity, extra values, and injected text', () => {
  const backend = validators();
  const attacks = [
    '0,0', 'NaN,106', 'Infinity,106', '-3,106,999',
    '-3;106', '-3,106<script>', '1e2,106', '', 'null',
  ];
  for (const value of attacks) {
    assert.throws(() => backend.validateCoordinate_(value));
  }
});

test('accepts legal coordinate boundaries but not whitespace-only tricks', () => {
  const backend = validators();
  assert.doesNotThrow(() => backend.validateCoordinate_('90, 180'));
  assert.doesNotThrow(() => backend.validateCoordinate_('-90, -180'));
  assert.throws(() => backend.validateCoordinate_('   '));
});
