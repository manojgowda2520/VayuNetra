import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';

class StorageService {
  static Future<void> savePendingReport(Map<String, dynamic> data) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(AppConstants.pendingReport, jsonEncode(data));
  }

  static Future<Map<String, dynamic>?> getPendingReport() async {
    final p = await SharedPreferences.getInstance();
    final d = p.getString(AppConstants.pendingReport);
    return d == null ? null : jsonDecode(d);
  }

  static Future<void> clearPendingReport() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(AppConstants.pendingReport);
  }

  static Future<String> getLanguage() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(AppConstants.langKey) ?? 'en';
  }

  static Future<void> setLanguage(String lang) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(AppConstants.langKey, lang);
  }
}
