import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../config/theme.dart';
import '../config/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../widgets/custom_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name    = TextEditingController();
  final _email   = TextEditingController();
  final _pass    = TextEditingController();
  final _confirm = TextEditingController();
  bool _showPass = false;

  bool get _match  => _pass.text == _confirm.text;
  bool get _strong => _pass.text.length >= 8;

  InputDecoration _dec(String hint, IconData icon) => InputDecoration(
    hintText: hint, hintStyle: const TextStyle(color: VNColors.muted, fontFamily: 'DMSans'),
    prefixIcon: Icon(icon, color: VNColors.muted, size: 20),
    filled: true, fillColor: VNColors.bgCard2,
    border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: VNColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: VNColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: VNColors.cyan, width: 1.5)),
  );

  void _register() async {
    if (!_match) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('passwordsDoNotMatch')), backgroundColor: VNColors.red));
      return;
    }
    final auth = context.read<AuthProvider>();
    final ok = await auth.register(_name.text.trim(), _email.text.trim(), _pass.text);
    if (!mounted) return;
    if (ok) {
      Navigator.pushReplacementNamed(context, AppConstants.home);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Registration failed'), backgroundColor: VNColors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VNColors.bg,
      appBar: AppBar(backgroundColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: VNColors.text), onPressed: () => Navigator.pop(context))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: FadeInUp(child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: VNColors.bgCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: VNColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.t('createAccount'), style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 28, fontWeight: FontWeight.bold, color: VNColors.text)),
            Text(context.t('joinCommunity'), style: const TextStyle(fontFamily: 'DMSans', fontSize: 13, color: VNColors.muted)),
            const SizedBox(height: 24),
            TextField(controller: _name, style: const TextStyle(color: VNColors.text, fontFamily: 'DMSans'), decoration: _dec(context.t('fullName'), Icons.person_outline)),
            const SizedBox(height: 14),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, style: const TextStyle(color: VNColors.text, fontFamily: 'DMSans'), decoration: _dec(context.t('emailAddress'), Icons.email_outlined)),
            const SizedBox(height: 14),
            TextField(
              controller: _pass, obscureText: !_showPass,
              style: const TextStyle(color: VNColors.text, fontFamily: 'DMSans'),
              onChanged: (_) => setState(() {}),
              decoration: _dec(context.t('passwordMin'), Icons.lock_outline).copyWith(
                suffixIcon: IconButton(icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility, color: VNColors.muted, size: 20),
                  onPressed: () => setState(() => _showPass = !_showPass)))),
            if (_pass.text.isNotEmpty) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(value: _strong ? 1.0 : 0.4, color: _strong ? VNColors.green : VNColors.orange, backgroundColor: VNColors.bgCard2, minHeight: 3),
              Text(_strong ? '${context.t('strongPassword')} ✓' : context.t('useEightChars'), style: TextStyle(fontSize: 11, color: _strong ? VNColors.green : VNColors.orange, fontFamily: 'DMSans')),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _confirm, obscureText: true,
              style: const TextStyle(color: VNColors.text, fontFamily: 'DMSans'),
              onChanged: (_) => setState(() {}),
              decoration: _dec(context.t('confirmPassword'), Icons.lock_outline).copyWith(
                suffixIcon: _confirm.text.isNotEmpty
                    ? Icon(_match ? Icons.check_circle : Icons.cancel, color: _match ? VNColors.green : VNColors.red, size: 20)
                    : null)),
            const SizedBox(height: 24),
            Consumer<AuthProvider>(builder: (_, auth, __) =>
              VNButton(label: context.t('createAccount'), loading: auth.loading, onTap: _register)),
          ]),
        )),
      ),
    );
  }
}
