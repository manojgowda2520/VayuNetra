import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import 'auth_service.dart';

class ApiService {
  static String get base => AppConstants.apiBaseUrl;

  static Future<Map<String, String>> _headers({bool auth = false}) async {
    final h = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await AuthService.getToken();
      if (token != null) h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  // ── AUTH ──────────────────────────────────────────────────
  static Future<Map<String, dynamic>> register(
      String name, String email, String password) async {
    final r = await http.post(
      Uri.parse('$base/api/auth/register'),
      headers: await _headers(),
      body: jsonEncode({
        'username': name,
        'email': email,
        'password': password,
      }),
    ).timeout(const Duration(seconds: 30));
    return jsonDecode(r.body);
  }

  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final r = await http.post(
      Uri.parse('$base/api/auth/login'),
      headers: await _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    ).timeout(const Duration(seconds: 30));
    return jsonDecode(r.body);
  }

  static Future<Map<String, dynamic>> getMe() async {
    final r = await http.get(
      Uri.parse('$base/api/auth/me'),
      headers: await _headers(auth: true),
    ).timeout(const Duration(seconds: 30));
    return jsonDecode(r.body);
  }

  // ── REPORTS ───────────────────────────────────────────────
  static Future<Map<String, dynamic>> submitReport({
    required String photoPath,
    required String area,
    required double lat,
    required double lng,
    required String description,
  }) async {
    final token = await AuthService.getToken();
    final req = http.MultipartRequest('POST', Uri.parse('$base/api/reports'));
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    req.headers['Accept'] = 'application/json';
    req.fields['area'] = area;
    req.fields['latitude'] = lat.toString();
    req.fields['longitude'] = lng.toString();
    req.fields['description'] = description;
    req.files.add(await http.MultipartFile.fromPath('photo', photoPath));
    final streamedResponse = await req.send().timeout(const Duration(seconds: 30));
    final res = await http.Response.fromStream(streamedResponse);

    // Debug: print status and first 200 chars
    print('Report response status: ${res.statusCode}');
    print('Report response body: ${res.body.substring(0, res.body.length > 200 ? 200 : res.body.length)}');

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Server error ${res.statusCode}: ${res.body.substring(0, res.body.length > 200 ? 200 : res.body.length)}');
    }
    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      final preview = res.body.length > 200 ? res.body.substring(0, 200) : res.body;
      throw Exception('Server returned non-JSON (possible redirect or error page). Status: ${res.statusCode}. Body: $preview');
    }
  }

  static Future<List<dynamic>> getReports({String? area}) async {
    final url = area != null
        ? '$base/api/search?area=$area'
        : '$base/api/reports';
    final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
    final b = jsonDecode(r.body);
    return b is List ? b : b['reports'] ?? [];
  }

  static Future<Map<String, dynamic>> getReport(int id) async {
    final r = await http.get(Uri.parse('$base/api/reports/$id'))
        .timeout(const Duration(seconds: 30));
    return jsonDecode(r.body);
  }

  static Future<List<dynamic>> getMyReports() async {
    final r = await http.get(
      Uri.parse('$base/api/my-reports'),
      headers: await _headers(auth: true),
    ).timeout(const Duration(seconds: 30));
    final b = jsonDecode(r.body);
    return b is List ? b : b['reports'] ?? [];
  }

  static Future<void> deleteReport(int id) async {
    await http.delete(
      Uri.parse('$base/api/reports/$id'),
      headers: await _headers(auth: true),
    ).timeout(const Duration(seconds: 30));
  }

  static Future<List<dynamic>> getSimilarReports(int id) async {
    final r = await http.get(Uri.parse('$base/api/similar/$id'))
        .timeout(const Duration(seconds: 30));
    final b = jsonDecode(r.body);
    return b is List ? b : [];
  }

  // ── NOVA ACT — Auto file KSPCB complaint ──────────────────
  static Future<Map<String, dynamic>> fileComplaintViaNovaAct(
      int reportId) async {
    final r = await http.post(
      Uri.parse('$base/api/file-complaint/$reportId'),
      headers: await _headers(auth: true),
    ).timeout(const Duration(seconds: 30));
    return jsonDecode(r.body);
  }

  // ── STATS ─────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getStats() async {
    final r = await http.get(Uri.parse('$base/api/stats'))
        .timeout(const Duration(seconds: 30));
    return jsonDecode(r.body);
  }

  static Future<List<dynamic>> getLeaderboard() async {
    final r = await http.get(Uri.parse('$base/api/leaderboard'))
        .timeout(const Duration(seconds: 30));
    final b = jsonDecode(r.body);
    return b is List ? b : b['leaderboard'] ?? [];
  }

  // ── CHAT (Nova 2 Lite agentic) ────────────────────────────
  static Future<Map<String, dynamic>> chat(
      String message, List<Map<String, String>> history) async {
    final r = await http.post(
      Uri.parse('$base/api/chat'),
      headers: await _headers(),
      body: jsonEncode({
        'message': message,
        'conversation_history': history,
      }),
    ).timeout(const Duration(seconds: 30));
    return jsonDecode(r.body);
  }

  // ── CLEAN ZONES ───────────────────────────────────────────
  static Future<List<dynamic>> getCleanZones() async {
    try {
      final r = await http.get(Uri.parse('$base/api/clean-zones'))
          .timeout(const Duration(seconds: 30));
      final b = jsonDecode(r.body);
      return b is List ? b : [];
    } catch (_) {
      return [];
    }
  }

  // ── VOICE (Nova 2 Sonic) ──────────────────────────────────
  static Future<Map<String, dynamic>> transcribeVoice(
      String audioPath, String language) async {
    final token = await AuthService.getToken();
    final req = http.MultipartRequest('POST', Uri.parse('$base/api/voice'));
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    req.fields['language'] = language;
    req.files.add(await http.MultipartFile.fromPath('audio', audioPath));
    final stream = await req.send().timeout(const Duration(seconds: 30));
    final res = await http.Response.fromStream(stream);
    return jsonDecode(res.body);
  }

  // ── HEALTH ────────────────────────────────────────────────
  static Future<Map<String, dynamic>> health() async {
    final r = await http.get(Uri.parse('$base/health'))
        .timeout(const Duration(seconds: 30));
    return jsonDecode(r.body);
  }
}
