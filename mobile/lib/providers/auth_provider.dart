import 'package:flutter/material.dart';
import 'dart:async';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  static const _tempEmail = 'demo@vayunetra.test';
  static const _tempPassword = 'Demo@123';

  User? _user;
  bool _loading = false;
  String? _error;

  User? get user => _user;
  bool get loading => _loading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;

  Future<void> _loginOffline() async {
    await AuthService.saveToken('temp-dev-token');
    _user = User(
      id: 1,
      name: 'Demo User',
      email: _tempEmail,
      points: 120,
      badgeLevel: 'Gold Protector',
      reportCount: 6,
      createdAt: DateTime(2026, 1, 1),
    );
    await AuthService.saveUser(_user!);
  }

  Future<bool> login(String email, String password) async {
    _loading = true; _error = null; notifyListeners();
    try {
      final res = await ApiService.login(email, password);
      if (res['token'] != null) {
        await AuthService.saveToken(res['token']);
        _user = User.fromJson(res['user']);
        await AuthService.saveUser(_user!);
        _loading = false; notifyListeners();
        return true;
      }
      _error = res['detail'] ?? 'Login failed';
    } catch (_) {
      if (email.trim().toLowerCase() == _tempEmail && password == _tempPassword) {
        await _loginOffline();
        _loading = false; notifyListeners();
        return true;
      }
      _error = 'Connection error. Is the backend running?';
    }
    _loading = false; notifyListeners();
    return false;
  }

  Future<bool> register(String name, String email, String password) async {
    _loading = true; _error = null; notifyListeners();
    try {
      final res = await ApiService.register(name, email, password);
      if (res['token'] != null) {
        await AuthService.saveToken(res['token']);
        _user = User.fromJson(res['user']);
        await AuthService.saveUser(_user!);
        _loading = false; notifyListeners();
        return true;
      }
      _error = res['detail'] ?? 'Registration failed';
    } catch (_) { _error = 'Connection error'; }
    _loading = false; notifyListeners();
    return false;
  }

  Future<void> loadUser() async {
    _user = await AuthService.getUser();
    if (_user != null) {
      try {
        final res = await ApiService.getMe().timeout(const Duration(milliseconds: 900));
        if (res['id'] != null) { _user = User.fromJson(res); await AuthService.saveUser(_user!); }
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> logout() async {
    await AuthService.clearAll();
    _user = null;
    notifyListeners();
  }
}
