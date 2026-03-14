import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/stats_provider.dart';
import '../providers/report_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/report_card.dart';
import '../widgets/vn_loading_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StatsProvider>().fetchStats();
      context.read<ReportProvider>().fetchMyReports();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth  = context.watch<AuthProvider>();
    final language = context.watch<LanguageProvider>();
    final stats = context.watch<StatsProvider>();
    final reps  = context.watch<ReportProvider>();
    final user  = auth.user;

    return Scaffold(
      backgroundColor: VNColors.bg,
      appBar: AppBar(
        backgroundColor: VNColors.bg,
        title: Row(children: [
          Container(width: 32, height: 32,
            decoration: BoxDecoration(shape: BoxShape.circle, color: VNColors.cyan.withOpacity(0.1), border: Border.all(color: VNColors.cyan)),
            child: const Icon(Icons.visibility, color: VNColors.cyan, size: 18)),
          const SizedBox(width: 8),
          Text(user != null ? 'Hey, ${user.name.split(' ').first}!' : 'VayuNetra',
            style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 20, color: VNColors.text)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.person_outline, color: VNColors.muted),
            onPressed: () => Navigator.pushNamed(context, AppConstants.profile)),
        ],
      ),
      body: RefreshIndicator(
        color: VNColors.cyan, backgroundColor: VNColors.bgCard,
        onRefresh: () async {
          await context.read<StatsProvider>().fetchStats();
          await context.read<ReportProvider>().fetchMyReports();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── QUICK ACTIONS ─────────────────────────────
            Text(language.t('quickActions'), style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 13, color: VNColors.muted, letterSpacing: 2)),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.2,
              children: [
                _QuickAction(icon: Icons.camera_alt_outlined, label: language.t('reportPollutionAction'), color: VNColors.saffron,
                  onTap: () => Navigator.pushNamed(context, AppConstants.report)),
                _QuickAction(icon: Icons.map_outlined, label: language.t('liveMap'), color: VNColors.cyan,
                  onTap: () => Navigator.pushNamed(context, AppConstants.map)),
                _QuickAction(icon: Icons.smart_toy_outlined, label: 'AI Chat', color: VNColors.purple,
                  onTap: () => Navigator.pushNamed(context, AppConstants.chat)),
                _QuickAction(icon: Icons.eco_outlined, label: language.t('cleanAir'), color: VNColors.green,
                  onTap: () => Navigator.pushNamed(context, AppConstants.cleanAir)),
              ],
            ),
            const SizedBox(height: 24),

            // ── STATS ─────────────────────────────────────
            Text(language.t('todayInBengaluru'), style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 13, color: VNColors.muted, letterSpacing: 2)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _StatBox(language.t('total'), '${stats.stats['total'] ?? 0}', VNColors.cyan, Icons.bar_chart)),
              const SizedBox(width: 8),
              Expanded(child: _StatBox(language.t('today'), '${stats.stats['today'] ?? 0}', VNColors.saffron, Icons.today)),
              const SizedBox(width: 8),
              Expanded(child: _StatBox(language.t('myReports'), '${reps.myReports.length}', VNColors.purple, Icons.article_outlined)),
            ]),
            const SizedBox(height: 24),

            // ── RECENT REPORTS ────────────────────────────
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(language.t('myRecentReports'), style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 13, color: VNColors.muted, letterSpacing: 2)),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, AppConstants.myReports),
                child: Text('${language.t('viewAll')} →', style: const TextStyle(fontFamily: 'DMSans', fontSize: 13, color: VNColors.cyan))),
            ]),
            const SizedBox(height: 10),
            if (reps.loading)
              const VNLoadingWidget()
            else if (reps.myReports.isEmpty)
              GlassCard(child: Center(child: Padding(padding: const EdgeInsets.all(20),
                child: Text(language.t('noReportsYet'), style: const TextStyle(color: VNColors.muted, fontFamily: 'DMSans'), textAlign: TextAlign.center))))
            else
              SizedBox(height: 215, child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: reps.myReports.take(5).length,
                itemBuilder: (_, i) => Padding(
                  padding: EdgeInsets.only(right: i < 4 ? 10 : 0),
                  child: SizedBox(width: 160, child: ReportCard(
                    report: reps.myReports[i],
                    onTap: () => Navigator.pushNamed(context, AppConstants.reportDetail, arguments: reps.myReports[i]),
                  )),
                ),
              )),
            const SizedBox(height: 24),

            // ── LEADERBOARD ───────────────────────────────
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(language.t('topReporters'), style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 13, color: VNColors.muted, letterSpacing: 2)),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, AppConstants.stats),
                child: Text('${language.t('seeAll')} →', style: const TextStyle(fontFamily: 'DMSans', fontSize: 13, color: VNColors.cyan))),
            ]),
            const SizedBox(height: 10),
            GlassCard(child: Column(
              children: stats.leaderboard.take(5).toList().asMap().entries.map((e) {
                final i = e.key; final row = e.value;
                final isMe = row['email'] == user?.email;
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isMe ? VNColors.cyan.withOpacity(0.05) : null,
                    border: isMe ? const Border(left: BorderSide(color: VNColors.cyan, width: 3)) : null,
                  ),
                  child: Row(children: [
                    SizedBox(width: 28, child: Text('${i + 1}', style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 16, color: VNColors.muted, fontWeight: FontWeight.bold))),
                    CircleAvatar(radius: 16, backgroundColor: VNColors.cyan.withOpacity(0.2),
                      child: Text((row['name'] ?? 'U')[0].toUpperCase(), style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.bold, color: VNColors.cyan))),
                    const SizedBox(width: 10),
                    Expanded(child: Text(row['name'] ?? '', style: const TextStyle(fontFamily: 'DMSans', fontSize: 14, color: VNColors.text))),
                    Text('${row['report_count'] ?? 0}', style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 16, fontWeight: FontWeight.bold, color: VNColors.cyan)),
                    Text(' ${language.t('reports').toLowerCase()}', style: const TextStyle(fontFamily: 'DMSans', fontSize: 11, color: VNColors.muted)),
                  ]),
                );
              }).toList(),
            )),
            const SizedBox(height: 80),
          ]),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (i) {
          final routes = [null, AppConstants.map, AppConstants.report, AppConstants.chat, AppConstants.profile];
          if (routes[i] != null) Navigator.pushNamed(context, routes[i]!);
        },
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: const Icon(Icons.map_outlined), label: language.t('liveMap')),
          BottomNavigationBarItem(icon: const Icon(Icons.camera_alt), label: language.t('report')),
          const BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          BottomNavigationBarItem(icon: const Icon(Icons.person_outline), label: language.t('profile')),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
      child: Row(children: [
        Icon(icon, color: color, size: 22), const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.bold, fontSize: 14, color: color))),
      ]),
    ),
  );
}

class _StatBox extends StatelessWidget {
  final String label, value; final Color color; final IconData icon;
  const _StatBox(this.label, this.value, this.color, this.icon);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.3))),
    child: Column(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontFamily: 'Rajdhani', fontSize: 24, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(fontFamily: 'DMSans', fontSize: 11, color: VNColors.muted)),
    ]),
  );
}
