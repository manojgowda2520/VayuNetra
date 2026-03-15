import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/constants.dart';
import '../models/report.dart';
import '../services/api_service.dart';

// #region agent log
void _debugLog(String location, String message, Map<String, dynamic> data, String hypothesisId) {
  final payload = {
    'sessionId': '478213',
    'runId': 'run1',
    'hypothesisId': hypothesisId,
    'location': location,
    'message': message,
    'data': data,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  };
  debugPrint('DEBUG $hypothesisId: $message ${jsonEncode(data)}');
  http.post(
    Uri.parse('http://127.0.0.1:7516/ingest/ef0eaa7e-adf7-4eab-9a4c-6c0f0831b6b0'),
    headers: {'Content-Type': 'application/json', 'X-Debug-Session-Id': '478213'},
    body: jsonEncode(payload),
  ).catchError((_) => http.Response('', 500));
}
// #endregion

class ReportProvider extends ChangeNotifier {
  List<Report> _reports = [];
  List<Report> _myReports = [];
  Report? _lastSubmitted;
  bool _loading = false;
  String? _error;

  List<Report> get reports => _reports;
  List<Report> get myReports => _myReports;
  Report? get lastSubmitted => _lastSubmitted;
  bool get loading => _loading;
  String? get error => _error;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> fetchReports({String? area}) async {
    _loading = true; _error = null; notifyListeners();
    try {
      final d = await ApiService.getReports(area: area).timeout(const Duration(seconds: 15));
      _reports = d.map((e) => Report.fromJson(e)).toList();
    } catch (e) {
      _reports = [];
      _error = 'Could not load reports. Please check your connection.';
    }
    _loading = false; notifyListeners();
  }

  Future<void> fetchMyReports() async {
    _loading = true; _error = null; notifyListeners();
    try {
      final d = await ApiService.getMyReports().timeout(const Duration(seconds: 15));
      _myReports = d.map((e) => Report.fromJson(e)).toList();
    } catch (e) {
      _myReports = [];
      _error = 'Could not load your reports. Please check your connection.';
    }
    _loading = false; notifyListeners();
  }

  Future<Report?> submitReport({
    required String photoPath, required String area,
    required double lat, required double lng, required String description,
  }) async {
    _loading = true; _error = null; notifyListeners();
    // #region agent log
    final baseUrl = AppConstants.apiBaseUrl;
    _debugLog('report_provider.dart:submitReport', 'submitReport started', {'baseUrl': baseUrl}, 'A');
    // #endregion
    try {
      final res = await ApiService.submitReport(
        photoPath: photoPath, area: area, lat: lat, lng: lng, description: description,
      ).timeout(const Duration(seconds: 60));
      // #region agent log
      _debugLog('report_provider.dart:submitReport', 'submitReport response', {'hasId': res['id'] != null, 'keys': res.keys.toList().toString()}, 'E');
      // #endregion
      if (res['id'] != null) {
        _lastSubmitted = Report.fromJson(res);
        _myReports = [_lastSubmitted!, ..._myReports];
        _loading = false; notifyListeners();
        return _lastSubmitted;
      }
      _error = res['detail'] ?? 'Submission failed';
    } catch (e, stack) {
      // #region agent log
      _debugLog('report_provider.dart:submitReport', 'submitReport catch', {'error': e.toString(), 'type': e.runtimeType.toString(), 'stackTrace': stack.toString().split('\n').take(3).join(' ')}, 'B');
      // #endregion
      _lastSubmitted = null;
      final msg = e.toString();
      _error = msg.contains('TimeoutException') || msg.contains('timeout')
          ? 'Request timed out. The server may be busy. Please try again.'
          : 'Submission failed. Please check your connection and try again.';
    }
    _loading = false; notifyListeners();
    return null;
  }

  Future<void> deleteReport(int id) async {
    await ApiService.deleteReport(id);
    _myReports.removeWhere((r) => r.id == id);
    notifyListeners();
  }
}
