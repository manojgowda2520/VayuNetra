import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../config/theme.dart';
import '../config/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/report_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _badges = [
    {'emoji': '🥉', 'name': 'Bronze Guardian',     'req': '1 report',    'color': 0xFFCD7F32},
    {'emoji': '🥈', 'name': 'Silver Watchdog',     'req': '5 reports',   'color': 0xFFC0C0C0},
    {'emoji': '🥇', 'name': 'Gold Protector',      'req': '20 reports',  'color': 0xFFFFD700},
    {'emoji': '💎', 'name': 'Diamond Sentinel',    'req': '50 reports',  'color': 0xFF00D4FF},
    {'emoji': '🌟', 'name': 'Legend of Bengaluru', 'req': '100 reports', 'color': 0xFFA855F7},
  ];
  static const _thresholds = [1, 5, 20, 50, 100];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final reps = context.watch<ReportProvider>();
    final language = context.watch<LanguageProvider>();
    final user = auth.user;

    if (user == null) return Scaffold(backgroundColor: VNColors.bg, body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(language.t('notLoggedIn'), style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 24, color: VNColors.text)), const SizedBox(height: 16),
      ElevatedButton(onPressed: () => Navigator.pushReplacementNamed(context, AppConstants.login),
        style: ElevatedButton.styleFrom(backgroundColor: VNColors.cyan),
        child: Text(language.t('login'), style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.bold, color: Colors.black))),
    ])));

    final count = reps.myReports.length;
    final bIdx = _thresholds.lastIndexWhere((t) => count >= t);
    final badge = bIdx >= 0 ? _badges[bIdx] : null;
    final nextBadge = bIdx < _badges.length - 1 ? _badges[bIdx + 1] : null;
    final nextT = bIdx < _thresholds.length - 1 ? _thresholds[bIdx + 1] : null;

    return Scaffold(
      backgroundColor: VNColors.bg,
      appBar: AppBar(backgroundColor: VNColors.bg, title: Text(language.t('profile'), style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 20, color: VNColors.text)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: VNColors.text), onPressed: () => Navigator.pop(context))),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
        CircleAvatar(radius: 44, backgroundColor: VNColors.cyan.withOpacity(0.15),
          child: Text(user.initials, style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 32, fontWeight: FontWeight.bold, color: VNColors.cyan))),
        const SizedBox(height: 12),
        Text(user.name, style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 26, fontWeight: FontWeight.bold, color: VNColors.text)),
        Text(user.email, style: const TextStyle(fontFamily: 'DMSans', fontSize: 13, color: VNColors.muted)),
        Text('${language.t('memberSince')} ${user.createdAt.year}', style: const TextStyle(fontFamily: 'DMSans', fontSize: 12, color: VNColors.muted)),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: _SBox(language.t('reports'), '$count', VNColors.cyan)),
          const SizedBox(width: 8),
          Expanded(child: _SBox(language.t('critical'), '${reps.myReports.where((r) => r.analysis?.severity == 'CRITICAL').length}', VNColors.red)),
          const SizedBox(width: 8),
          Expanded(child: _SBox(language.t('points'), '${user.points}', VNColors.yellow)),
        ]),
        const SizedBox(height: 24),
        if (badge != null) Container(padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: VNColors.bgCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: VNColors.border)),
          child: Column(children: [
            Text(badge['emoji'] as String, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 4),
            Text(badge['name'] as String, style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 20, fontWeight: FontWeight.bold, color: VNColors.text)),
            if (nextBadge != null && nextT != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: count / nextT, color: VNColors.cyan, backgroundColor: VNColors.bgCard2, minHeight: 6),
              const SizedBox(height: 4),
              Text('${nextT - count} more to reach ${nextBadge['name']}',
                style: const TextStyle(fontFamily: 'DMSans', fontSize: 12, color: VNColors.muted)),
            ],
          ])),
        const SizedBox(height: 24),
        Align(alignment: Alignment.centerLeft, child: Text(language.t('badges'), style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 13, color: VNColors.muted, letterSpacing: 2))),
        const SizedBox(height: 12),
        GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 2.1, mainAxisSpacing: 8, crossAxisSpacing: 8),
          itemCount: _badges.length,
          itemBuilder: (_, i) {
            final b = _badges[i]; final unlocked = count >= _thresholds[i];
            return Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: unlocked ? Color(b['color'] as int).withOpacity(0.1) : VNColors.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: unlocked ? Color(b['color'] as int).withOpacity(0.5) : VNColors.border)),
              child: Row(children: [
                Text(unlocked ? b['emoji'] as String : '🔒', style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(
                    b['name'] as String,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Rajdhani', fontSize: 11, fontWeight: FontWeight.bold, color: unlocked ? VNColors.text : VNColors.muted),
                  ),
                  Text(b['req'] as String, style: const TextStyle(fontFamily: 'DMSans', fontSize: 10, color: VNColors.muted)),
                ])),
              ]));
          }),
        const SizedBox(height: 24),
        Align(alignment: Alignment.centerLeft, child: Text(language.t('language'), style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 13, color: VNColors.muted, letterSpacing: 2))),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: VNColors.bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: VNColors.border)),
          child: Row(children: [
            {'code': 'en', 'label': language.t('english')},
            {'code': 'kn', 'label': language.t('kannada')},
            {'code': 'hi', 'label': language.t('hindi')},
          ].map((l) {
            final active = language.languageCode == l['code'];
            return Expanded(child: GestureDetector(onTap: () async { await language.setLanguage(l['code']!); },
              child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: active ? VNColors.cyan : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                child: Text(l['label']!, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.bold, fontSize: 14, color: active ? Colors.black : VNColors.muted)))));
          }).toList())),
        const SizedBox(height: 24),
        ListTile(leading: const Icon(Icons.share_outlined, color: VNColors.text, size: 22), title: Text(language.t('shareApp'), style: const TextStyle(fontFamily: 'DMSans', color: VNColors.text)), trailing: const Icon(Icons.chevron_right, color: VNColors.muted, size: 20), contentPadding: EdgeInsets.zero, onTap: () => Share.share('Check out VayuNetra — air quality app for Bengaluru: https://vayunetra.com/download')),
        ListTile(leading: const Icon(Icons.logout, color: VNColors.red, size: 22), title: Text(language.t('logout'), style: const TextStyle(fontFamily: 'DMSans', color: VNColors.red)), trailing: const Icon(Icons.chevron_right, color: VNColors.muted, size: 20), contentPadding: EdgeInsets.zero,
          onTap: () async { await auth.logout(); if (context.mounted) Navigator.pushReplacementNamed(context, AppConstants.login); }),
        const SizedBox(height: 40),
      ])),
    );
  }
}

class _SBox extends StatelessWidget {
  final String label, value; final Color color;
  const _SBox(this.label, this.value, this.color);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.3))),
    child: Column(children: [
      Text(value, style: TextStyle(fontFamily: 'Rajdhani', fontSize: 24, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(fontFamily: 'DMSans', fontSize: 11, color: VNColors.muted)),
    ]));
}
