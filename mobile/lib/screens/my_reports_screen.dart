import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/constants.dart';
import '../providers/report_provider.dart';
import '../providers/language_provider.dart';
import '../models/report.dart';
import '../widgets/report_card.dart';
import '../widgets/vn_loading_widget.dart';
import '../widgets/custom_button.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});
  @override State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  String _filter = 'All';
  final _filters = ['All', 'Critical', 'High', 'Moderate', 'Low'];

  @override void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => context.read<ReportProvider>().fetchMyReports()); }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();
    return Scaffold(
      backgroundColor: VNColors.bg,
      appBar: AppBar(backgroundColor: VNColors.bg,
        title: Consumer<ReportProvider>(builder: (_, r, __) =>
          Text('${language.t('myReports')} (${r.myReports.length})', style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 20, color: VNColors.text))),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: VNColors.text), onPressed: () => Navigator.pop(context))),
      body: Consumer<ReportProvider>(builder: (_, reps, __) {
        if (reps.loading) return VNLoadingWidget(message: language.t('loadingReports'));
        final filtered = _filter == 'All' ? reps.myReports
            : reps.myReports.where((r) => r.analysis?.severity.toUpperCase() == _filter.toUpperCase()).toList();

        return Column(children: [
          SizedBox(height: 50, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: _filters.map((f) {
              final active = _filter == f;
              return Padding(padding: const EdgeInsets.only(right: 8), child: FilterChip(
                label: Text(f, style: TextStyle(fontFamily: 'DMSans', fontSize: 12, color: active ? Colors.black : VNColors.text)),
                selected: active, onSelected: (_) => setState(() => _filter = f),
                selectedColor: VNColors.cyan, backgroundColor: VNColors.bgCard,
                side: BorderSide(color: active ? VNColors.cyan : VNColors.border), showCheckmark: false));
            }).toList())),

          Expanded(child: filtered.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.visibility_off, color: VNColors.muted, size: 60), const SizedBox(height: 16),
                  Text(_filter == 'All' ? language.t('noReportsYet') : 'No $_filter ${language.t('reports').toLowerCase()}',
                    style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 20, color: VNColors.text)),
                  const SizedBox(height: 24),
                  SizedBox(width: 180, child: VNButton(label: language.t('reportAgain'), icon: Icons.camera_alt, color: VNColors.saffron,
                    onTap: () => Navigator.pushNamed(context, AppConstants.report))),
                ]))
              : RefreshIndicator(color: VNColors.cyan, onRefresh: () => reps.fetchMyReports(),
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.75),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => ReportCard(report: filtered[i],
                    onTap: () => Navigator.pushNamed(context, AppConstants.reportDetail, arguments: filtered[i]))))),
        ]);
      }),
    );
  }
}
