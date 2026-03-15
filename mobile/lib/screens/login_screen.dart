import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../config/theme.dart';
import '../config/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../widgets/custom_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass  = TextEditingController();
  bool _showPass = false;

  InputDecoration _dec(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: VNColors.muted, fontFamily: 'DMSans'),
    prefixIcon: Icon(icon, color: VNColors.muted, size: 20),
    filled: true, fillColor: VNColors.bgCard2,
    border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: VNColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: VNColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: VNColors.cyan, width: 1.5)),
  );

  void _login() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_email.text.trim(), _pass.text);
    if (!mounted) return;
    if (ok) {
      Navigator.pushReplacementNamed(context, AppConstants.home);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? context.t('login')), backgroundColor: VNColors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VNColors.bg,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(center: Alignment.topCenter, radius: 0.8,
            colors: [VNColors.cyan.withOpacity(0.05), VNColors.bg])),
        child: SafeArea(child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const SizedBox(height: 40),
            FadeInDown(
              child: Column(children: [
                Image.asset('assets/images/logo.png', width: 100, height: 100, fit: BoxFit.contain),
                const SizedBox(height: 12),
                const Text('VayuNetra', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 32, fontWeight: FontWeight.bold, color: VNColors.cyan)),
                Text(context.t('appSubtitleNative'), style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 16, color: VNColors.purple, fontStyle: FontStyle.italic)),
              ]),
            ),
            const SizedBox(height: 40),
            FadeInUp(delay: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: VNColors.bgCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: VNColors.border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(context.t('welcomeBack'), style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 26, fontWeight: FontWeight.bold, color: VNColors.text)),
                  Text(context.t('loginToReport'), style: const TextStyle(fontFamily: 'DMSans', fontSize: 13, color: VNColors.muted)),
                  const SizedBox(height: 24),
                  TextField(controller: _email, keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: VNColors.text, fontFamily: 'DMSans'),
                    decoration: _dec(context.t('emailAddress'), Icons.email_outlined)),
                  const SizedBox(height: 14),
                  TextField(controller: _pass, obscureText: !_showPass,
                    style: const TextStyle(color: VNColors.text, fontFamily: 'DMSans'),
                    decoration: _dec(context.t('password'), Icons.lock_outline).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility, color: VNColors.muted, size: 20),
                        onPressed: () => setState(() => _showPass = !_showPass)))),
                  const SizedBox(height: 24),
                  Consumer<AuthProvider>(builder: (_, auth, __) =>
                    VNButton(label: context.t('login'), loading: auth.loading, onTap: _login)),
                ]),
              )),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('${context.t('newHere')} ', style: const TextStyle(color: VNColors.muted, fontFamily: 'DMSans')),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, AppConstants.register),
                child: Text(context.t('register'), style: const TextStyle(color: VNColors.cyan, fontFamily: 'DMSans', fontWeight: FontWeight.bold))),
            ]),
          ]),
        )),
      ),
    );
  }
}
