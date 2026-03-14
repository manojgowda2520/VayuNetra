import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/constants.dart';
import '../models/user.dart';

class AuthService {
  static const _s = FlutterSecureStorage();

  static Future<void> saveToken(String token) =>
      _s.write(key: AppConstants.tokenKey, value: token);

  static Future<String?> getToken() =>
      _s.read(key: AppConstants.tokenKey);

  static Future<void> saveUser(User user) => _s.write(
    key: AppConstants.userKey,
    value: jsonEncode({
      'id': user.id, 'name': user.name, 'email': user.email,
      'points': user.points, 'badge_level': user.badgeLevel,
      'report_count': user.reportCount,
      'created_at': user.createdAt.toIso8601String(),
    }),
  );

  static Future<User?> getUser() async {
    final d = await _s.read(key: AppConstants.userKey);
    if (d == null) return null;
    return User.fromJson(jsonDecode(d));
  }

  static Future<void> clearAll() => _s.deleteAll();
}
