import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'config/theme.dart';
import 'config/constants.dart';
import 'providers/auth_provider.dart';
import 'providers/report_provider.dart';
import 'providers/location_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/stats_provider.dart';
import 'providers/language_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/report_screen.dart';
import 'screens/report_detail_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/my_reports_screen.dart';
import 'screens/clean_air_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/profile_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env.development');
  runApp(const VayuNetraApp());
}

class VayuNetraApp extends StatelessWidget {
  const VayuNetraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ReportProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => StatsProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: Consumer<LanguageProvider>(
        builder: (_, __, ___) => MaterialApp(
          title: 'VayuNetra',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          initialRoute: AppConstants.splash,
          routes: {
            AppConstants.splash:       (_) => const SplashScreen(),
            AppConstants.login:        (_) => const LoginScreen(),
            AppConstants.register:     (_) => const RegisterScreen(),
            AppConstants.home:         (_) => const HomeScreen(),
            AppConstants.map:          (_) => const MapScreen(),
            AppConstants.report:       (_) => const ReportScreen(),
            AppConstants.reportDetail: (_) => const ReportDetailScreen(),
            AppConstants.chat:         (_) => const ChatScreen(),
            AppConstants.myReports:    (_) => const MyReportsScreen(),
            AppConstants.cleanAir:     (_) => const CleanAirScreen(),
            AppConstants.stats:        (_) => const StatsScreen(),
            AppConstants.profile:      (_) => const ProfileScreen(),
          },
        ),
      ),
    );
  }
}
