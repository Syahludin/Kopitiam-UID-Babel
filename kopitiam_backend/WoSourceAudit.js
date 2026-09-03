function auditWoSources() {
  var spreadsheet = SpreadsheetApp.openById(CONFIG.WO_SPREADSHEET_ID);
  var names = [
    CONFIG.WO_INSJAR_SHEET,
    CONFIG.WO_INSDU_SHEET,
    CONFIG.WO_ROW_SHEET,
    CONFIG.WO_HAR_JAR_SHEET,
    CONFIG.WO_HAR_DU_SHEET,
  ];
  var report = {
    spreadsheetId: spreadsheet.getId(),
    spreadsheetName: spreadsheet.getName(),
    sheets: {},
  };
  names.forEach(function (name) {
    if (!name) return;
    var sheet = spreadsheet.getSheetByName(name);
    if (!sheet) {
      report.sheets[name] = { exists: false };
      return;
    }
    var values = sheet.getDataRange().getDisplayValues();
    var headers = values.length ? values[0].map(function (v) { return String(v).trim(); }) : [];
    var index = headerIndex_(headers);
    var samples = [];
    for (var row = 1; row < values.length && samples.length < 5; row++) {
      if (index["kode wo"] === undefined || !String(values[row][index["kode wo"]] || "").trim()) continue;
      samples.push({
        kodeWo: String(values[row][index["kode wo"]] || "").trim(),
        kodeUlp: index["kode ulp"] === undefined ? "" : String(values[row][index["kode ulp"]] || "").trim(),
        ulp: index.ulp === undefined ? "" : String(values[row][index.ulp] || "").trim(),
        status: index["status wo"] === undefined ? "" : String(values[row][index["status wo"]] || "").trim(),
        timEksekusi: index["tim eksekusi"] === undefined ? "" : String(values[row][index["tim eksekusi"]] || "").trim(),
      });
    }
    report.sheets[name] = {
      exists: true,
      rows: Math.max(0, values.length - 1),
      headersValid: index["kode wo"] !== undefined && index["kode ulp"] !== undefined,
      samples: samples,
    };
  });
  console.log(JSON.stringify(report, null, 2));
  return report;
}
