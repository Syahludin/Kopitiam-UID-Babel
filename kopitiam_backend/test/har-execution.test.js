'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const source=fs.readFileSync(path.join(__dirname,'../HarExecution.js'),'utf8');
function table(headers,rows=[]){
  const data=[headers.slice(),...rows.map(r=>headers.map(h=>r[h]??''))];
  return {data,getDataRange:()=>({getDisplayValues:()=>data.map(r=>r.map(String))}),appendRow:r=>data.push(r),getRange:(r,c)=>({setValue:v=>{if(!data[r-1])data[r-1]=[];data[r-1][c-1]=v;}})};
}
function setup(mode='jar'){
  let uploads=0,locked=0;
  const s={username:mode==='jar'?'koba.harjar':'koba.hardu',subTim:mode==='jar'?'Har Jar':'Har Du',tim:'Regu 1',kodeUlp:'16140'};
  const sandbox={console:{error(){}},CONFIG:{WO_SPREADSHEET_ID:'wo',WO_HAR_JAR_SHEET:'WO_Har_Jar',WO_HAR_DU_SHEET:'WO_Har_Du'},normalize_:v=>String(v??'').trim().toLowerCase(),normalizeCode_:v=>String(v??'').replace(/[^0-9A-Z]/gi,'').toUpperCase(),safeCell_:v=>String(v??''),cekSesi_:()=>({success:true,sesi:s}),fail_:(kode,message)=>({success:false,kode,message}),LockService:{getScriptLock:()=>({waitLock(){locked++;},releaseLock(){locked--;}})},preparePhoto_:(b)=>{if(b!=='jpeg')throw Error('Invalid photo');return {digest:'a'.repeat(64)};},folderPath_:p=>p,putPhotoIdempotent_:(folder,code)=>{uploads++;return {name:code+'.Foto Sesudah.'+'a'.repeat(24)+'.jpg',url:'https://drive.example/photo'};}};
  vm.createContext(sandbox);vm.runInContext(source,sandbox);
  const h={ 'Kode WO':'HAR-001','Kode Temuan':'INS-001.TO-001','Kode UIW':'16','Kode UP3':'161','Kode ULP':'16140','ULP':'Koba','Jenis WO':mode==='jar'?'WO Har Jar':'WO Har Du','Jenis Object':mode==='jar'?'Jaringan':'Gardu','Tim Eksekusi':'Regu 1','Status WO':'Menunggu','Waktu Mulai':'','Waktu Selesai':'','Folder Path':'Kopitiam/parent/','Foto Sesudah':'','Link Foto Sesudah':'','Catatan Petugas':'','User Input':'','Penyulang':'Koba','Section':'A-B','Segmen':mode==='jar'?'A1':'','Nomor Gardu':mode==='du'?'G1':'','Temuan':'Isolator','Tier':'Tier 1','Prioritas':'Mayor','Hari':'Selasa','Tanggal':'08 September 2026','Koordinat':'-2,106','Lat':'-2','Long':'106','Extra Formula':'=SUM(A1:A2)'};
  const sheets={};sheets[mode==='jar'?'WO_Har_Jar':'WO_Har_Du']=table(Object.keys(h),[h]);
  sheets.Pekerjaan_WO_Har=table(Array.from(sandbox.HAR_JOB_HEADERS_));
  sheets.Material_WO_Har=table(Array.from(sandbox.HAR_MATERIAL_HEADERS_));
  const master=table(['No','Kode Material','Nama Material','Satuan Material','Status Baris'],[{'No':'1','Kode Material':'M1','Nama Material':'Isolator','Satuan Material':'Pcs','Status Baris':'Aktif'}]);
  sandbox.SpreadsheetApp={openById:()=>({getSheetByName:n=>sheets[n]}),flush(){}};
  sandbox.getSpreadsheet_=()=>({getSheetByName:()=>master});
  const job={...h,'Kode Pekerjaan':'PKJ-'+'1'.repeat(32),'Uraian Pekerjaan':'Ganti isolator','Jumlah':2,'Set':'Set','Waktu Input':'08 September 2026, 10:00:00'};
  const material={...h,'Kode Penggunaan Material':'MAT-'+'2'.repeat(32),'Kode Pekerjaan':job['Kode Pekerjaan'],'Material':'Isolator','Jumlah':2,'Satuan':'Pcs','Kepemilikan':'PLN','Waktu Input':job['Waktu Input']};
  const input={...h,schemaVersion:2,'Status WO':'Progress Pekerjaan','Waktu Mulai':'08 September 2026, 09:00:00',jobs:[job],materials:[material]};
  return {api:sandbox,s,h,input,master,sheets,mode,uploads:()=>uploads,locked:()=>locked,run:()=>sandbox.syncHarExecution_('token',mode,[input])};
}
test('Har Jar and Har Du persist jobs/material with server-derived lineage',()=>{
  for(const mode of ['jar','du']){const t=setup(mode);t.input.jobs[0]['Koordinat']='spoof';t.input.materials[0]['User Input']='spoof';assert.equal(t.run().success,true);const job=t.sheets.Pekerjaan_WO_Har.data;assert.equal(job.length,2);assert.equal(job[1][job[0].indexOf('Koordinat')],'-2,106');const mat=t.sheets.Material_WO_Har.data;assert.equal(mat[1][mat[0].indexOf('Satuan')],'Pcs');assert.equal(mat[1][mat[0].indexOf('User Input')],t.s.username);assert.equal(t.locked(),0);}
});
test('progress retry reuses child IDs instead of appending duplicates',()=>{const t=setup();assert.equal(t.run().success,true);assert.equal(t.run().success,true);assert.equal(t.sheets.Pekerjaan_WO_Har.data.length,2);assert.equal(t.sheets.Material_WO_Har.data.length,2);});
test('completion preserves parent folder, coordinates and unrelated formulas',()=>{const t=setup();t.input['Status WO']='Selesai';t.input['Waktu Selesai']='08 September 2026, 11:00:00';t.input.fotoSesudahBase64='jpeg';t.input['Folder Path']='evil/';assert.equal(t.run().success,true);const data=t.sheets.WO_Har_Jar.data;assert.equal(data[1][data[0].indexOf('Folder Path')],'Kopitiam/parent/');assert.equal(data[1][data[0].indexOf('Extra Formula')],'=SUM(A1:A2)');assert.equal(t.run().success,true);assert.equal(t.uploads(),1);t.input.jobs[0]['Uraian Pekerjaan']='changed';assert.equal(t.run().success,false);});
test('invalid quantity, stale unit, unknown material and missing photo fail before writes',()=>{
  for(const mutate of [t=>t.input.materials[0].Jumlah=-1,t=>t.input.materials[0].Satuan='Meter',t=>t.input.materials[0].Material='Tidak ada',t=>{t.input['Status WO']='Selesai';t.input['Waktu Selesai']='now';},t=>t.input.jobs[0].Jumlah=Infinity]){const t=setup();mutate(t);assert.equal(t.run().success,false);assert.equal(t.sheets.Pekerjaan_WO_Har.data.length,1);assert.equal(t.uploads(),0);assert.equal(t.locked(),0);}
});
test('rejects foreign ULP/team and Har Jar cannot impersonate Har Du',()=>{const t=setup();assert.equal(t.api.harAllowed_(t.s,'du'),false);t.s.kodeUlp='16310';assert.equal(t.run().success,false);t.s.kodeUlp='16140';t.s.tim='Other';assert.equal(t.run().success,false);});
test('download only exposes assigned WO and rejects missing schema',()=>{const t=setup();assert.equal(t.api.getHarExecution_('token','jar').rows.length,1);t.s.tim='Other';assert.equal(t.api.getHarExecution_('token','jar').rows.length,0);delete t.sheets.WO_Har_Jar;assert.equal(t.api.getHarExecution_('token','jar').success,false);});
test('partial child write can be retried safely; status is not prematurely complete',()=>{const t=setup();const append=t.sheets.Material_WO_Har.appendRow;t.sheets.Material_WO_Har.appendRow=()=>{throw Error('transient');};assert.equal(t.run().success,false);assert.equal(t.sheets.WO_Har_Jar.data[1][t.sheets.WO_Har_Jar.data[0].indexOf('Status WO')],'Menunggu');t.sheets.Material_WO_Har.appendRow=append;assert.equal(t.run().success,true);assert.equal(t.sheets.Pekerjaan_WO_Har.data.length,2);});
test('material header aliases accepted and inactive rows rejected',()=>{const t=setup();t.sheets.Material_WO_Har.data[0]=t.sheets.Material_WO_Har.data[0].map(h=>h==='Kode Pekerjaan'?'Kode Pekerjaan WO Har':h==='Kode WO'?'Kode WO Har':h);assert.equal(t.run().success,true);const other=setup();other.master.data[1][4]='Nonaktif';assert.equal(other.run().success,false);});
