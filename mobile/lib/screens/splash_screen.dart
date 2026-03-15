import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _status = '';

  @override
  void initState() {
    super.initState();
    _status = context.read<LanguageProvider>().t('preparingDashboard');
    _init();
  }

  Future<void> _init() async {
    await Future.delayed(const Duration(milliseconds: 350));
    if (mounted) {
      setState(() => _status = context.read<LanguageProvider>().t('loadingInsights'));
    }
    if (!mounted) return;
    try {
      final result = await ApiService.health();
      print('Health: $result');
    } catch (e) {
      print('Health check failed: $e');
    }
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    await auth.loadUser();
    if (mounted) {
      setState(() => _status = context.read<LanguageProvider>().t('readyToExplore'));
    }
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      Navigator.pushReplacementNamed(context, auth.isLoggedIn ? AppConstants.home : AppConstants.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();
    return Scaffold(
      backgroundColor: VNColors.bg,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter, radius: 1.2,
            colors: [VNColors.cyan.withOpacity(0.08), VNColors.bg],
          ),
        ),
        child: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            FadeInDown(
              child: Image.asset(
                'assets/images/logo.png',
                width: 170,
                height: 170,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 20),
            FadeInUp(delay: const Duration(milliseconds: 300),
              child: const Text('VayuNetra', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 48, fontWeight: FontWeight.bold, color: VNColors.cyan, letterSpacing: 2))),
            FadeInUp(delay: const Duration(milliseconds: 450),
              child: Text(language.t('appSubtitleNative'), style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 20, color: VNColors.purple, fontStyle: FontStyle.italic, letterSpacing: 4))),
            FadeInUp(delay: const Duration(milliseconds: 550),
              child: Text(language.t('appTagline'), style: const TextStyle(fontFamily: 'DMSans', fontSize: 13, color: VNColors.muted, fontStyle: FontStyle.italic))),
            const SizedBox(height: 60),
            Text(_status, style: const TextStyle(fontFamily: 'DMSans', fontSize: 13, color: VNColors.muted)),
            const SizedBox(height: 12),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.2, end: 1),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeInOut,
              builder: (_, value, __) => SizedBox(
                width: 90 + (value * 60),
                child: LinearProgressIndicator(
                  color: VNColors.cyan,
                  backgroundColor: VNColors.bgCard2,
                  minHeight: 3,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
