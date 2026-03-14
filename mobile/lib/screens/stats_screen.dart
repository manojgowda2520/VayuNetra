import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../config/theme.dart';
import '../providers/stats_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/report_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/vn_loading_widget.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override void initState() { super.initState(); _tab = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) { context.read<StatsProvider>().fetchStats(); context.read<ReportProvider>().fetchMyReports(); }); }
  @override void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: VNColors.bg,
    appBar: AppBar(backgroundColor: VNColors.bg,
      title: Text(context.t('statistics'), style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 20, color: VNColors.text)),
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: VNColors.text), onPressed: () => Navigator.pop(context)),
      bottom: TabBar(controller: _tab, indicatorColor: VNColors.cyan, labelColor: VNColors.cyan, unselectedLabelColor: VNColors.muted,
        labelStyle: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.bold, fontSize: 15),
        tabs: [Tab(text: context.t('personal')), Tab(text: context.t('community'))])),
    body: TabBarView(controller: _tab, children: [_Personal(), _Community()]),
  );
}

class _Personal extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final all = context.watch<ReportProvider>().myReports;
    final bySeverity = {'Critical': all.where((r) => r.analysis?.severity == 'CRITICAL').length, 'High': all.where((r) => r.analysis?.severity == 'HIGH').length, 'Moderate': all.where((r) => r.analysis?.severity == 'MODERATE').length, 'Low': all.where((r) => r.analysis?.severity == 'LOW').length};
    final colors = {'Critical': VNColors.red, 'High': VNColors.orange, 'Moderate': VNColors.yellow, 'Low': VNColors.green};

    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(context.t('yourImpact'), style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 13, color: VNColors.muted, letterSpacing: 2)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _Box(context.t('reports'), '${all.length}', VNColors.cyan)),
        const SizedBox(width: 8),
        Expanded(child: _Box(context.t('critical'), '${bySeverity['Critical']}', VNColors.red)),
        const SizedBox(width: 8),
        Expanded(child: _Box(context.t('points'), '${context.watch<AuthProvider>().user?.points ?? 0}', VNColors.yellow)),
      ]),
      if (all.isNotEmpty) ...[
        const SizedBox(height: 24),
        Text(context.t('severityBreakdown'), style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 13, color: VNColors.muted, letterSpacing: 2)),
        const SizedBox(height: 12),
        GlassCard(child: SizedBox(height: 200, child: PieChart(PieChartData(
          sections: bySeverity.entries.where((e) => e.value > 0).map((e) => PieChartSectionData(
            value: e.value.toDouble(), title: '${e.key}\n${e.value}',
            color: colors[e.key]!, radius: 60,
            titleStyle: const TextStyle(fontFamily: 'Rajdhani', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white))).toList(),
          sectionsSpace: 2, centerSpaceRadius: 30)))),
      ],
    ]));
  }
}

class _Community extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final stats = context.watch<StatsProvider>();
    if (stats.loading) return VNLoadingWidget(message: context.t('loadingCommunityStats'));
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(context.t('bengaluruCommunity'), style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 13, color: VNColors.muted, letterSpacing: 2)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _Box(context.t('total'), '${stats.stats['total'] ?? 0}', VNColors.cyan)),
        const SizedBox(width: 8),
        Expanded(child: _Box(context.t('today'), '${stats.stats['today'] ?? 0}', VNColors.saffron)),
        const SizedBox(width: 8),
        Expanded(child: _Box(context.t('areas'), '${stats.stats['areas'] ?? 0}', VNColors.purple)),
      ]),
      const SizedBox(height: 24),
      Text(context.t('fullLeaderboard'), style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 13, color: VNColors.muted, letterSpacing: 2)),
      const SizedBox(height: 12),
      GlassCard(child: Column(children: stats.leaderboard.asMap().entries.map((e) {
        final i = e.key; final row = e.value;
        return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [
          SizedBox(width: 32, child: Text('${i + 1}', style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 16, color: VNColors.muted, fontWeight: FontWeight.bold))),
          CircleAvatar(radius: 16, backgroundColor: VNColors.cyan.withOpacity(0.15),
            child: Text((row['name'] ?? 'U')[0].toUpperCase(), style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.bold, color: VNColors.cyan))),
          const SizedBox(width: 10),
          Expanded(child: Text(row['name'] ?? '', style: const TextStyle(fontFamily: 'DMSans', fontSize: 14, color: VNColors.text))),
          Text('${row['report_count'] ?? 0}', style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 16, fontWeight: FontWeight.bold, color: VNColors.cyan)),
          Text(' ${context.t('reports').toLowerCase()}', style: const TextStyle(fontFamily: 'DMSans', fontSize: 11, color: VNColors.muted)),
        ]));
      }).toList())),
    ]));
  }
}

class _Box extends StatelessWidget {
  final String label, value; final Color color;
  const _Box(this.label, this.value, this.color);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.3))),
    child: Column(children: [
      Text(value, style: TextStyle(fontFamily: 'Rajdhani', fontSize: 24, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(fontFamily: 'DMSans', fontSize: 11, color: VNColors.muted)),
    ]));
}
