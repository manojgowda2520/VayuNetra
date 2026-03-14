import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  static String get apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000';

  static const String splash      = '/';
  static const String login       = '/login';
  static const String register    = '/register';
  static const String home        = '/home';
  static const String map         = '/map';
  static const String report      = '/report';
  static const String reportDetail = '/report-detail';
  static const String chat        = '/chat';
  static const String myReports   = '/my-reports';
  static const String cleanAir    = '/clean-air';
  static const String stats       = '/stats';
  static const String profile     = '/profile';

  static const String tokenKey      = 'vayunetra_token';
  static const String userKey       = 'vayunetra_user';
  static const String pendingReport = 'pending_report';
  static const String langKey       = 'vn_language';
}
