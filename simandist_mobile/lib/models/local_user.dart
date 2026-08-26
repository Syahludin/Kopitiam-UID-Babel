class LocalUser {
  final int? id;
  final String remoteNo;
  final String kodeUiw;
  final String kodeUp3;
  final String kodeUlp;
  final String ulp;
  final String username;
  final String passwordHash;
  final String passwordSalt;
  final String role;
  final String bidang;
  final String tim;
  final String subTim;
  final String aksesMenu;
  final bool isActive;
  final String? sourceUpdatedAt;
  final String syncedAt;

  const LocalUser({
    this.id,
    required this.remoteNo,
    required this.kodeUiw,
    required this.kodeUp3,
    required this.kodeUlp,
    required this.ulp,
    required this.username,
    required this.passwordHash,
    required this.passwordSalt,
    required this.role,
    required this.bidang,
    required this.tim,
    required this.subTim,
    required this.aksesMenu,
    required this.isActive,
    this.sourceUpdatedAt,
    required this.syncedAt,
  });

  factory LocalUser.fromRemote(Map<String, dynamic> row, {
    required String passwordHash,
    required String passwordSalt,
    required String syncedAt,
  }) {
    return LocalUser(
      remoteNo: '${row['no'] ?? ''}',
      kodeUiw: '${row['kodeUiw'] ?? ''}',
      kodeUp3: '${row['kodeUp3'] ?? ''}',
      kodeUlp: '${row['kodeUlp'] ?? ''}',
      ulp: '${row['ulp'] ?? ''}',
      username: '${row['username'] ?? ''}'.trim().toLowerCase(),
      passwordHash: passwordHash,
      passwordSalt: passwordSalt,
      role: '${row['role'] ?? ''}',
      bidang: '${row['bidang'] ?? ''}',
      tim: '${row['tim'] ?? ''}',
      subTim: '${row['subTim'] ?? ''}',
      aksesMenu: '${row['aksesMenu'] ?? ''}',
      isActive: row['isActive'] != false,
      sourceUpdatedAt: row['sourceUpdatedAt']?.toString(),
      syncedAt: syncedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'remote_no': remoteNo,
        'kode_uiw': kodeUiw,
        'kode_up3': kodeUp3,
        'kode_ulp': kodeUlp,
        'ulp': ulp,
        'username': username,
        'password_hash': passwordHash,
        'password_salt': passwordSalt,
        'role': role,
        'bidang': bidang,
        'tim': tim,
        'sub_tim': subTim,
        'akses_menu': aksesMenu,
        'is_active': isActive ? 1 : 0,
        'source_updated_at': sourceUpdatedAt,
        'synced_at': syncedAt,
      };
}
