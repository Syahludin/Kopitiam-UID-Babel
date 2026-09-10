"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const root = path.resolve(__dirname, "..");
const source = fs.readFileSync(
  path.join(root, "ZZ_MasterDataFiltered.js"),
  "utf8",
);

function load() {
  const sandbox = {
    normalize_: (value) => String(value || "").trim().toLowerCase(),
    headerIndex_: (headers) => Object.fromEntries(
      headers.map((value, index) => [String(value).trim().toLowerCase(), index]),
    ),
    CONFIG: { USERS_SHEET: "User_App_Mobile" },
    USER_COL: { username: 0 },
  };
  vm.createContext(sandbox);
  vm.runInContext(source, sandbox, { filename: "ZZ_MasterDataFiltered.js" });
  return sandbox;
}

test("Master Temuan accepts production inspection label variants", () => {
  const api = load();
  const sheet = {
    getDataRange: () => ({
      getDisplayValues: () => [
        ["Objek Inspeksi", "Tier", "Temuan"],
        ["Inspeksi Jaringan", "Tier 1", "Kabel Geser"],
        ["Jaringan", "Tier 2", "Andongan Rendah"],
        ["Inspeksi Gardu", "Tier 1", "Trafo Bocor"],
      ],
    }),
  };

  const rows = api.masterRows_(
    sheet,
    "Master_Temuan",
    { username: "petugas", subTim: "Inspeksi Jaringan" },
    api.masterObjectForSession_({ subTim: "Inspeksi Jaringan" }),
  );

  assert.deepEqual(
    rows.map((row) => row.Temuan),
    ["Kabel Geser", "Andongan Rendah"],
  );
});

test("object aliases normalize to the mobile categories", () => {
  const api = load();
  assert.equal(api.masterObjectCategory_("INSJAR"), "jaringan");
  assert.equal(api.masterObjectCategory_("JTM / JTR"), "jaringan");
  assert.equal(api.masterObjectCategory_("Inspeksi Gardu"), "gardu");
});
