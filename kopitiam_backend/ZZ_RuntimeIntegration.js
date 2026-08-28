/*
 * Guard telah diintegrasikan langsung ke Code.js dan IdempotentUpload.js.
 * File ini dipertahankan untuk kompatibilitas clasp push dan node --check.
 *
 * - doPost: quota check + runtimeIdentity_ → Code.js doPost
 * - cekPerangkat_: validateDeviceRecord_ + accountStatus_ → Code.js cekPerangkat_
 * - cekSesi_: verifySessionDeviceBinding_ → Code.js cekSesi_
 * - syncTemuanInspeksiIdempotent_: validateFindingMaster_ → IdempotentUpload.js
 */
