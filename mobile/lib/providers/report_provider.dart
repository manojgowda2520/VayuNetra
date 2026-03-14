import 'package:flutter/material.dart';
import 'dart:async';
import '../models/report.dart';
import '../services/api_service.dart';

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

  List<Report> _demoReports() {
    final now = DateTime.now();
    return [
      Report(
        id: 101,
        userId: 1,
        area: 'Silk Board Junction',
        latitude: 12.9177,
        longitude: 77.6238,
        description: 'Heavy traffic smoke during peak hours.',
        photoUrl: null,
        status: 'reviewed',
        createdAt: now.subtract(const Duration(minutes: 40)),
        analysis: AnalysisResult(
          severity: 'HIGH',
          pollutionType: 'Vehicle Emissions',
          healthRisk: 'Sensitive groups may feel irritation and breathing discomfort.',
          description: 'Dense roadside emissions and repeated signal congestion are affecting local air quality.',
          confidence: 0.91,
          recommendations: ['Avoid long exposure during rush hour', 'Use a mask if commuting daily'],
          complaintLetter: '',
        ),
      ),
      Report(
        id: 102,
        userId: 1,
        area: 'Whitefield Main Road',
        latitude: 12.9698,
        longitude: 77.7500,
        description: 'Dust near construction stretch.',
        photoUrl: null,
        status: 'reviewed',
        createdAt: now.subtract(const Duration(hours: 3)),
        analysis: AnalysisResult(
          severity: 'MODERATE',
          pollutionType: 'Construction Dust',
          healthRisk: 'Can trigger mild throat and eye irritation nearby.',
          description: 'Open debris and active construction appear to be causing particulate dust in the area.',
          confidence: 0.86,
          recommendations: ['Reduce outdoor exposure nearby', 'Report uncovered debris to local authorities'],
          complaintLetter: '',
        ),
      ),
      Report(
        id: 103,
        userId: 2,
        area: 'Koramangala 5th Block',
        latitude: 12.9352,
        longitude: 77.6245,
        description: 'Open waste burning spotted near roadside.',
        photoUrl: null,
        status: 'critical',
        createdAt: now.subtract(const Duration(hours: 7)),
        analysis: AnalysisResult(
          severity: 'CRITICAL',
          pollutionType: 'Open Waste Burning',
          healthRisk: 'Smoke may cause acute breathing discomfort and eye irritation.',
          description: 'Visible smoke plume and burning waste indicate severe local air quality impact.',
          confidence: 0.95,
          recommendations: ['Move away from the smoke source', 'Escalate the report to the municipality immediately'],
          complaintLetter: '',
        ),
      ),
    ];
  }

  Future<void> fetchReports({String? area}) async {
    _loading = true; notifyListeners();
    try {
      final d = await ApiService.getReports(area: area).timeout(const Duration(milliseconds: 1200));
      _reports = d.map((e) => Report.fromJson(e)).toList();
    } catch (e) {
      final fallback = _demoReports();
      _reports = area == null
          ? fallback
          : fallback.where((r) => r.area.toLowerCase().contains(area.toLowerCase())).toList();
      _error = null;
    }
    _loading = false; notifyListeners();
  }

  Future<void> fetchMyReports() async {
    _loading = true; notifyListeners();
    try {
      final d = await ApiService.getMyReports().timeout(const Duration(milliseconds: 1200));
      _myReports = d.map((e) => Report.fromJson(e)).toList();
    } catch (e) {
      _myReports = _demoReports().where((r) => r.userId == 1).toList();
      _error = null;
    }
    _loading = false; notifyListeners();
  }

  Future<Report?> submitReport({
    required String photoPath, required String area,
    required double lat, required double lng, required String description,
  }) async {
    _loading = true; _error = null; notifyListeners();
    try {
      final res = await ApiService.submitReport(
        photoPath: photoPath, area: area, lat: lat, lng: lng, description: description);
      if (res['id'] != null) {
        _lastSubmitted = Report.fromJson(res);
        _myReports = [_lastSubmitted!, ..._myReports];
        _loading = false; notifyListeners();
        return _lastSubmitted;
      }
      _error = res['detail'] ?? 'Submission failed';
    } catch (e) {
      _lastSubmitted = Report(
        id: DateTime.now().millisecondsSinceEpoch,
        userId: 1,
        area: area,
        latitude: lat,
        longitude: lng,
        description: description,
        photoUrl: null,
        status: 'reviewed',
        createdAt: DateTime.now(),
        analysis: AnalysisResult(
          severity: 'MODERATE',
          pollutionType: 'Air Quality Alert',
          healthRisk: 'Moderate local exposure may cause irritation for sensitive groups.',
          description: 'This is a local demo analysis generated because the backend is not connected yet.',
          confidence: 0.82,
          recommendations: ['Avoid the hotspot for extended periods', 'Track whether smoke or dust persists'],
          complaintLetter: '',
        ),
      );
      _myReports = [_lastSubmitted!, ..._myReports];
      _error = null;
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
