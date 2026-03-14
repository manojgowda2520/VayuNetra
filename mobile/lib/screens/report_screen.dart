import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:animate_do/animate_do.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import '../config/theme.dart';
import '../config/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/report_provider.dart';
import '../providers/location_provider.dart';
import '../services/storage_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/severity_badge.dart';
import '../widgets/complaint_letter_widget.dart';
import '../config/theme.dart' show severityColor, severityEmoji;

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  int _step = 0;
  XFile? _photo;
  final _area = TextEditingController();
  final _desc = TextEditingController();
  bool _analyzing = false;
  String _analysisMsg = '';
  final _picker = ImagePicker();

  Future<void> _pick(ImageSource src) async {
    final img = await _picker.pickImage(source: src, imageQuality: 85);
    if (img != null) setState(() => _photo = img);
  }

  Future<void> _getLocation() async {
    final loc = context.read<LocationProvider>();
    await loc.getCurrentLocation();
    if (loc.areaName.isNotEmpty && !loc.areaName.contains('error') && !loc.areaName.contains('denied')) {
      _area.text = loc.areaName;
    }
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      await StorageService.savePendingReport({
        'photoPath': _photo!.path, 'area': _area.text,
        'lat': context.read<LocationProvider>().lat ?? 12.9716,
        'lng': context.read<LocationProvider>().lng ?? 77.5946,
        'description': _desc.text,
      });
      _showLoginGate();
      return;
    }
    setState(() { _analyzing = true; _analysisMsg = context.t('uploadingPhoto'); });
    await Future.delayed(const Duration(milliseconds: 900));
    setState(() => _analysisMsg = context.t('analyzingPollution'));
    await Future.delayed(const Duration(milliseconds: 900));
    setState(() => _analysisMsg = context.t('generatingComplaint'));

    final loc  = context.read<LocationProvider>();
    final reps = context.read<ReportProvider>();
    await reps.submitReport(
      photoPath: _photo!.path, area: _area.text,
      lat: loc.lat ?? 12.9716, lng: loc.lng ?? 77.5946,
      description: _desc.text,
    );
    setState(() { _analyzing = false; _step = 2; });
  }

  void _showLoginGate() {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: VNColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _LoginGate(onSuccess: () async {
          Navigator.pop(context);
          final p = await StorageService.getPendingReport();
          if (p != null) {
            _area.text = p['area'] ?? ''; _desc.text = p['description'] ?? '';
            await StorageService.clearPendingReport();
            await _submit();
          }
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: VNColors.bg,
    appBar: AppBar(backgroundColor: VNColors.bg,
      title: Text(context.t('reportPollution'), style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 20, color: VNColors.text)),
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: VNColors.text), onPressed: () => Navigator.pop(context))),
    body: _step == 0 ? _step1() : _step == 1 ? _step2() : _result(),
  );

  // ── STEP 1: PHOTO ─────────────────────────────────
  Widget _step1() => SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
    _Steps(step: 0), const SizedBox(height: 24),
    GestureDetector(onTap: () => _pick(ImageSource.camera),
      child: Container(height: 260, width: double.infinity,
        decoration: BoxDecoration(color: VNColors.bgCard, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _photo != null ? VNColors.cyan : VNColors.border, width: _photo != null ? 2 : 1)),
        child: _photo == null
            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.camera_alt_outlined, color: VNColors.cyan, size: 64),
                const SizedBox(height: 12),
                Text(context.t('tapToTakePhoto'), style: const TextStyle(fontFamily: 'DMSans', color: VNColors.muted, fontSize: 15)),
                Text(context.t('orUseButtons'), style: const TextStyle(fontFamily: 'DMSans', color: VNColors.muted, fontSize: 13)),
              ])
            : Stack(children: [
                ClipRRect(borderRadius: BorderRadius.circular(14),
                  child: Image.file(File(_photo!.path), fit: BoxFit.cover, width: double.infinity, height: double.infinity)),
                Positioned(top: 8, right: 8, child: GestureDetector(onTap: () => setState(() => _photo = null),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                    child: const Text('Change', style: TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'DMSans'))))),
              ]),
      )),
    const SizedBox(height: 14),
    Row(children: [
      Expanded(child: VNButton(label: context.t('camera'), icon: Icons.camera_alt, outlined: true, onTap: () => _pick(ImageSource.camera))),
      const SizedBox(width: 10),
      Expanded(child: VNButton(label: context.t('gallery'), icon: Icons.photo_library, outlined: true, color: VNColors.cyan, onTap: () => _pick(ImageSource.gallery))),
    ]),
    const SizedBox(height: 24),
    VNButton(label: '${context.t('nextAddDetails')} →', color: VNColors.saffron, onTap: _photo == null ? null : () => setState(() => _step = 1)),
  ]));

  // ── STEP 2: DETAILS ───────────────────────────────
  Widget _step2() {
    final loc = context.watch<LocationProvider>();
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Steps(step: 1), const SizedBox(height: 24),
      TextField(controller: _area,
        style: const TextStyle(color: VNColors.text, fontFamily: 'DMSans'),
        decoration: InputDecoration(hintText: context.t('areaHint'),
          hintStyle: const TextStyle(color: VNColors.muted), prefixIcon: const Icon(Icons.location_on_outlined, color: VNColors.muted),
          filled: true, fillColor: VNColors.bgCard,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: VNColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: VNColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: VNColors.cyan)))),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: _getLocation,
        icon: loc.loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: VNColors.cyan, strokeWidth: 2)) : const Icon(Icons.my_location, color: VNColors.cyan, size: 18),
        label: Text(loc.loading ? context.t('detecting') : context.t('useMyGpsLocation'), style: const TextStyle(color: VNColors.cyan, fontFamily: 'DMSans')),
        style: OutlinedButton.styleFrom(side: const BorderSide(color: VNColors.cyan))),
      if (loc.lat != null) Padding(padding: const EdgeInsets.only(top: 4),
        child: Text('GPS: ${loc.lat!.toStringAsFixed(4)}, ${loc.lng!.toStringAsFixed(4)}', style: const TextStyle(fontSize: 11, color: VNColors.muted, fontFamily: 'DMSans'))),
      const SizedBox(height: 16),
      TextField(controller: _desc, maxLines: 4,
        style: const TextStyle(color: VNColors.text, fontFamily: 'DMSans'),
        decoration: InputDecoration(hintText: context.t('descriptionHint'),
          hintStyle: const TextStyle(color: VNColors.muted),
          filled: true, fillColor: VNColors.bgCard,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: VNColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: VNColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: VNColors.cyan)))),
      const SizedBox(height: 12),
      Container(padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: VNColors.cyan.withOpacity(0.07), borderRadius: BorderRadius.circular(10), border: Border.all(color: VNColors.border)),
        child: Row(children: [
          const Icon(Icons.auto_awesome, color: VNColors.cyan, size: 18), const SizedBox(width: 8),
          Expanded(child: Text(context.t('novaDescription'), style: const TextStyle(fontFamily: 'DMSans', fontSize: 12, color: VNColors.muted))),
        ])),
      const SizedBox(height: 24),
      Row(children: [
        Expanded(child: VNButton(label: '${context.t('back')} ←', outlined: true, color: VNColors.muted, onTap: () => setState(() => _step = 0))),
        const SizedBox(width: 10),
        Expanded(child: Consumer<ReportProvider>(builder: (_, reps, __) =>
          VNButton(label: '${context.t('analyze')} →', loading: _analyzing, color: VNColors.saffron,
            onTap: _area.text.isEmpty ? null : _submit))),
      ]),
      if (_analyzing) ...[
        const SizedBox(height: 24),
        Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: VNColors.bgCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: VNColors.cyan.withOpacity(0.3))),
          child: Column(children: [
            Pulse(infinite: true, child: const Icon(Icons.visibility, color: VNColors.cyan, size: 48)),
            const SizedBox(height: 12),
            Text(context.t('novaAnalyzing'), style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 18, color: VNColors.cyan, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_analysisMsg, style: const TextStyle(fontFamily: 'DMSans', fontSize: 13, color: VNColors.muted)),
          ])),
      ],
    ]));
  }

  // ── STEP 3: RESULT ────────────────────────────────
  Widget _result() {
    final report = context.watch<ReportProvider>().lastSubmitted;
    final analysis = report?.analysis;
      if (analysis == null) return const Center(child: Text('No result', style: TextStyle(color: VNColors.muted)));

    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: FadeInUp(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Steps(step: 2),
      const SizedBox(height: 20),

      // Severity banner
      Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(color: severityColor(analysis.severity).withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: severityColor(analysis.severity))),
        child: Column(children: [
          Text('${severityEmoji(analysis.severity)} ${analysis.severity} POLLUTION',
            style: TextStyle(fontFamily: 'Rajdhani', fontSize: 24, fontWeight: FontWeight.bold, color: severityColor(analysis.severity))),
          Text(analysis.pollutionType, style: const TextStyle(fontFamily: 'DMSans', fontSize: 15, color: VNColors.text)),
        ])),
      const SizedBox(height: 14),

      // Health risk
      Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: VNColors.yellow.withOpacity(0.07), borderRadius: BorderRadius.circular(10), border: Border.all(color: VNColors.yellow.withOpacity(0.4))),
        child: Row(children: [
          const Icon(Icons.health_and_safety_outlined, color: VNColors.yellow, size: 22), const SizedBox(width: 10),
          Expanded(child: Text(analysis.healthRisk, style: const TextStyle(fontFamily: 'DMSans', fontSize: 13, color: VNColors.text))),
        ])),
      const SizedBox(height: 14),

      Text(analysis.description, style: const TextStyle(fontFamily: 'DMSans', fontSize: 14, color: VNColors.text, height: 1.6)),
      const SizedBox(height: 14),

      // Confidence
      Row(children: [
        Text('${context.t('confidence')}: ', style: const TextStyle(fontFamily: 'DMSans', fontSize: 13, color: VNColors.muted)),
        Text('${(analysis.confidence * 100).toInt()}%', style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 16, fontWeight: FontWeight.bold, color: VNColors.cyan)),
      ]),
      const SizedBox(height: 6),
      LinearPercentIndicator(percent: analysis.confidence, lineHeight: 6, progressColor: VNColors.cyan, backgroundColor: VNColors.bgCard2, barRadius: const Radius.circular(3), padding: EdgeInsets.zero),
      const SizedBox(height: 16),

      // Recommendations
      if (analysis.recommendations.isNotEmpty)
        Container(padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: VNColors.bgCard, borderRadius: BorderRadius.circular(12), border: const Border(left: BorderSide(color: VNColors.cyan, width: 3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Icon(Icons.lightbulb_outline, color: VNColors.cyan, size: 18), const SizedBox(width: 6),
              Text(context.t('recommendations'), style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.bold, fontSize: 16, color: VNColors.cyan))]),
            const SizedBox(height: 8),
            ...analysis.recommendations.map((r) => Padding(padding: const EdgeInsets.only(top: 4),
              child: Text('• $r', style: const TextStyle(fontFamily: 'DMSans', fontSize: 13, color: VNColors.text)))),
          ])),
      const SizedBox(height: 16),

      // Complaint letter
      if (analysis.complaintLetter.isNotEmpty) ...[
        ComplaintLetterWidget(letter: analysis.complaintLetter), const SizedBox(height: 16)],

      // Actions
      Row(children: [
        Expanded(child: VNButton(label: context.t('myReports'), outlined: true, icon: Icons.list, onTap: () => Navigator.pushNamed(context, AppConstants.myReports))),
        const SizedBox(width: 10),
        Expanded(child: VNButton(label: context.t('reportAgain'), icon: Icons.add_a_photo, color: VNColors.saffron,
          onTap: () => setState(() { _step = 0; _photo = null; _area.clear(); _desc.clear(); }))),
      ]),
      const SizedBox(height: 40),
    ])));
  }
}

class _Steps extends StatelessWidget {
  final int step;
  const _Steps({required this.step});
  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
    ...List.generate(3, (i) => Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(shape: BoxShape.circle,
        color: i <= step ? VNColors.cyan.withOpacity(0.2) : VNColors.bgCard,
        border: Border.all(color: i <= step ? VNColors.cyan : VNColors.border, width: i == step ? 2 : 1)),
      child: Center(child: Text('${i + 1}', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.bold,
        color: i <= step ? VNColors.cyan : VNColors.muted)))))),
  ]);
}

class _LoginGate extends StatefulWidget {
  final VoidCallback onSuccess;
  const _LoginGate({required this.onSuccess});
  @override State<_LoginGate> createState() => _LoginGateState();
}

class _LoginGateState extends State<_LoginGate> {
  final _e = TextEditingController(); final _p = TextEditingController();
  void _login() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_e.text.trim(), _p.text);
    if (ok && mounted) widget.onSuccess();
  }
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(context.t('loginToSubmit'), style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 22, fontWeight: FontWeight.bold, color: VNColors.text)),
      Text(context.t('photoSavedLogin'), style: const TextStyle(fontFamily: 'DMSans', fontSize: 13, color: VNColors.muted)),
      const SizedBox(height: 16),
      TextField(controller: _e, style: const TextStyle(color: VNColors.text),
        decoration: InputDecoration(hintText: context.t('emailAddress'), hintStyle: const TextStyle(color: VNColors.muted), filled: true, fillColor: VNColors.bgCard,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: VNColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: VNColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: VNColors.cyan)))),
      const SizedBox(height: 10),
      TextField(controller: _p, obscureText: true, style: const TextStyle(color: VNColors.text),
        decoration: InputDecoration(hintText: context.t('password'), hintStyle: const TextStyle(color: VNColors.muted), filled: true, fillColor: VNColors.bgCard,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: VNColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: VNColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: VNColors.cyan)))),
      const SizedBox(height: 16),
      Consumer<AuthProvider>(builder: (_, auth, __) =>
        VNButton(label: context.t('loginSubmit'), loading: auth.loading, onTap: _login)),
      const SizedBox(height: 16),
    ]),
  );
}
