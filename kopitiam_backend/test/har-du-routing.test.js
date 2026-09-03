const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = path.resolve(__dirname, '..');
const code = fs.readFileSync(path.join(root, 'Code.js'), 'utf8');
const audit = fs.readFileSync(path.join(root, 'WoSourceAudit.js'), 'utf8');

test('konfigurasi menunjuk sheet WO Har Du produksi', () => {
  assert.match(code, /WO_HAR_DU_SHEET:\s*["']WO_Har_Du["']/);
});

test('router API menangani download dan sinkron WO Har Du', () => {
  assert.ok(code.includes('if (a === "getWoHarDu") return json_(getWoHarDu_(b.token));'));
  assert.ok(code.includes('if (a === "syncWoHarDu") return json_(syncWoHarDu_(b.token, b.rows));'));
});

test('handler Har Du memvalidasi sesi, akses, sumber sheet, dan filter ULP', () => {
  assert.ok(code.includes('function getWoHarDu_(t)'));
  assert.ok(code.includes('var ac = woHarAccess_(a.sesi, "du");'));
  assert.ok(code.includes('getSheetByName(CONFIG.WO_HAR_DU_SHEET)'));
  assert.ok(code.includes('if (rowKodeUlp !== ac.kodeUlp)'));
});

test('sinkron Har Du memakai handler generik pada sheet yang benar', () => {
  assert.ok(code.includes('function syncWoHarDu_(t, rows)'));
  assert.ok(code.includes('return syncGenericWoHar_(a.sesi, CONFIG.WO_HAR_DU_SHEET, rows);'));
});

test('audit sumber mencakup WO Har Du', () => {
  assert.ok(audit.includes('CONFIG.WO_HAR_DU_SHEET'));
});
