import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../models/local_user.dart';
import 'sqlite_service.dart';

class LocalUserRepository {
  LocalUserRepository({SqliteService? database}) : _database = database ?? SqliteService.instance;

  final SqliteService _database;

  Future<void> saveFromOnlineProfile({
    required Map<String, dynamic> profile,
    required String password,
  }) async {
    final salt = _salt();
    final user = LocalUser.fromRemote(
      profile,
      passwordHash: _hash(password, salt),
      passwordSalt: salt,
      syncedAt: DateTime.now().toUtc().toIso8601String(),
    );
    await _database.upsertUsers([user]);
  }

  Future<LocalUser?> loginOffline(String username, String password) async {
    final user = await _database.findUser(username);
    if (user == null || !_equals(_hash(password, user.passwordSalt), user.passwordHash)) {
      return null;
    }
    return user;
  }

  String _hash(String password, String salt) {
    var value = '$salt:$password';
    for (var i = 0; i < 12000; i++) {
      value = sha256.convert(utf8.encode(value)).toString();
    }
    return value;
  }

  String _salt() {
    final random = Random.secure();
    return base64UrlEncode(List<int>.generate(32, (_) => random.nextInt(256)));
  }

  bool _equals(String left, String right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var i = 0; i < left.length; i++) {
      difference |= left.codeUnitAt(i) ^ right.codeUnitAt(i);
    }
    return difference == 0;
  }
}
