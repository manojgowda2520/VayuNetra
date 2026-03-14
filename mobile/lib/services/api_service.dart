import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import 'auth_service.dart';

class ApiService {
  static String get base => AppConstants.apiBaseUrl;

  static Future<Map<String, String>> _h({bool auth = false}) async {
    final h = {'Content-Type': 'application/json'};
    if (auth) {
      final t = await AuthService.getToken();
      if (t != null) h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  // AUTH
  static Future<Map<String, dynamic>> register(String name, String email, String password) async {
    final r = await http.post(Uri.parse('$base/api/auth/register'),
      headers: await _h(), body: jsonEncode({'name': name, 'email': email, 'password': password}));
    return jsonDecode(r.body);
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final r = await http.post(Uri.parse('$base/api/auth/login'),
      headers: await _h(), body: jsonEncode({'email': email, 'password': password}));
    return jsonDecode(r.body);
  }

  static Future<Map<String, dynamic>> getMe() async {
    final r = await http.get(Uri.parse('$base/api/auth/me'), headers: await _h(auth: true));
    return jsonDecode(r.body);
  }

  // REPORTS
  static Future<Map<String, dynamic>> submitReport({
    required String photoPath, required String area,
    required double lat, required double lng, required String description,
  }) async {
    final token = await AuthService.getToken();
    final req = http.MultipartRequest('POST', Uri.parse('$base/api/reports'));
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    req.fields['area'] = area;
    req.fields['latitude'] = lat.toString();
    req.fields['longitude'] = lng.toString();
    req.fields['description'] = description;
    req.files.add(await http.MultipartFile.fromPath('photo', photoPath));
    final res = await http.Response.fromStream(await req.send());
    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> getReports({String? area}) async {
    final url = area != null ? '$base/api/search?area=$area' : '$base/api/reports';
    final r = await http.get(Uri.parse(url));
    final b = jsonDecode(r.body);
    return b is List ? b : b['reports'] ?? [];
  }

  static Future<Map<String, dynamic>> getReport(int id) async {
    final r = await http.get(Uri.parse('$base/api/reports/$id'));
    return jsonDecode(r.body);
  }

  static Future<List<dynamic>> getMyReports() async {
    final r = await http.get(Uri.parse('$base/api/my-reports'), headers: await _h(auth: true));
    final b = jsonDecode(r.body);
    return b is List ? b : b['reports'] ?? [];
  }

  static Future<void> deleteReport(int id) async {
    await http.delete(Uri.parse('$base/api/reports/$id'), headers: await _h(auth: true));
  }

  static Future<List<dynamic>> getSimilarReports(int id) async {
    final r = await http.get(Uri.parse('$base/api/similar/$id'));
    final b = jsonDecode(r.body);
    return b is List ? b : b['reports'] ?? [];
  }

  // STATS
  static Future<Map<String, dynamic>> getStats() async {
    final r = await http.get(Uri.parse('$base/api/stats'));
    return jsonDecode(r.body);
  }

  static Future<List<dynamic>> getLeaderboard() async {
    final r = await http.get(Uri.parse('$base/api/leaderboard'));
    final b = jsonDecode(r.body);
    return b is List ? b : b['leaderboard'] ?? [];
  }

  // CHAT
  static Future<Map<String, dynamic>> chat(String message, List<Map<String, String>> history) async {
    final r = await http.post(Uri.parse('$base/api/chat'),
      headers: await _h(), body: jsonEncode({'message': message, 'conversation_history': history}));
    return jsonDecode(r.body);
  }

  // CLEAN ZONES
  static Future<List<dynamic>> getCleanZones() async {
    try {
      final r = await http.get(Uri.parse('$base/api/clean-zones'));
      final b = jsonDecode(r.body);
      return b is List ? b : b['zones'] ?? [];
    } catch (_) { return []; }
  }

  // VOICE
  static Future<Map<String, dynamic>> transcribeVoice(String audioPath, String language) async {
    final token = await AuthService.getToken();
    final req = http.MultipartRequest('POST', Uri.parse('$base/api/voice'));
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    req.fields['language'] = language;
    req.files.add(await http.MultipartFile.fromPath('audio', audioPath));
    final res = await http.Response.fromStream(await req.send());
    return jsonDecode(res.body);
  }

  // HEALTH
  static Future<Map<String, dynamic>> health() async {
    final r = await http.get(Uri.parse('$base/health'));
    return jsonDecode(r.body);
  }
}
