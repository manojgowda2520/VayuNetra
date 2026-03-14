import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';

class StatsProvider extends ChangeNotifier {
  Map<String, dynamic> _stats = {};
  List<dynamic> _leaderboard = [];
  bool _loading = false;

  Map<String, dynamic> get stats => _stats;
  List<dynamic> get leaderboard => _leaderboard;
  bool get loading => _loading;

  Future<void> fetchStats() async {
    _loading = true; notifyListeners();
    try {
      _stats = await ApiService.getStats().timeout(const Duration(milliseconds: 1200));
      _leaderboard = await ApiService.getLeaderboard().timeout(const Duration(milliseconds: 1200));
    } catch (_) {
      _stats = {
        'total': 248,
        'today': 17,
        'areas': 34,
      };
      _leaderboard = [
        {'name': 'Demo User', 'email': 'demo@vayunetra.test', 'report_count': 6},
        {'name': 'Asha Rao', 'email': 'asha@example.com', 'report_count': 18},
        {'name': 'Rahul N', 'email': 'rahul@example.com', 'report_count': 14},
        {'name': 'Meera K', 'email': 'meera@example.com', 'report_count': 11},
        {'name': 'Naveen P', 'email': 'naveen@example.com', 'report_count': 9},
      ];
    }
    _loading = false; notifyListeners();
  }
}
