import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/constants.dart';
import '../models/report.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/report_provider.dart';
import '../widgets/severity_badge.dart';
import '../widgets/complaint_letter_widget.dart';
import '../config/theme.dart' show severityColor;
import 'package:timeago/timeago.dart' as timeago;

class ReportDetailScreen extends StatelessWidget {
  const ReportDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final report = ModalRoute.of(context)!.settings.arguments as Report;
    final analysis = report.analysis;
    final auth = context.watch<AuthProvider>();
    final reps = context.read<ReportProvider>();
    final isOwner = auth.user?.id == report.userId;

    return Scaffold(
      backgroundColor: VNColors.bg,
      appBar: AppBar(
        backgroundColor: VNColors.bg,
        title: Text(report.area, style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 18, color: VNColors.text)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: VNColors.text), onPressed: () => Navigator.pop(context)),
        actions: [
          if (isOwner) IconButton(
            icon: const Icon(Icons.delete_outline, color: VNColors.red),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: VNColors.bgCard,
                  title: const Text('Delete Report?', style: TextStyle(fontFamily: 'Rajdhani', color: VNColors.text)),
                  content: const Text('This cannot be undone.', style: TextStyle(fontFamily: 'DMSans', color: VNColors.muted)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: VNColors.muted))),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: VNColors.red))),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await reps.deleteReport(report.id);
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Photo
          if (report.photoUrl != null)
            CachedNetworkImage(
              imageUrl: report.photoUrl!,
              height: 240, width: double.infinity, fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(height: 240, color: VNColors.bgCard2,
                child: const Icon(Icons.image, color: VNColors.muted, size: 80)),
            ),

          Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Header
            Row(children: [
              Expanded(child: Text(report.area, style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 24, fontWeight: FontWeight.bold, color: VNColors.text))),
              if (analysis != null) SeverityBadge(severity: analysis.severity),
            ]),
            const SizedBox(height: 4),
            Text(timeago.format(report.createdAt), style: const TextStyle(fontFamily: 'DMSans', fontSize: 12, color: VNColors.muted)),
            Text('${report.latitude.toStringAsFixed(4)}, ${report.longitude.toStringAsFixed(4)}', style: const TextStyle(fontFamily: 'DMSans', fontSize: 11, color: VNColors.muted)),

            if (analysis != null) ...[
              const SizedBox(height: 16),

              // Pollution type
              Text(analysis.pollutionType, style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 20, fontWeight: FontWeight.bold, color: VNColors.cyan)),
              const SizedBox(height: 8),

              // Health risk
              Container(padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: VNColors.yellow.withOpacity(0.07), borderRadius: BorderRadius.circular(10), border: Border.all(color: VNColors.yellow.withOpacity(0.4))),
                child: Row(children: [
                  const Icon(Icons.health_and_safety_outlined, color: VNColors.yellow, size: 20), const SizedBox(width: 8),
                  Expanded(child: Text(analysis.healthRisk, style: const TextStyle(fontFamily: 'DMSans', fontSize: 13, color: VNColors.text))),
                ])),
              const SizedBox(height: 12),

              Text(analysis.description, style: const TextStyle(fontFamily: 'DMSans', fontSize: 14, color: VNColors.text, height: 1.6)),
              const SizedBox(height: 12),

              // Confidence
              Row(children: [
                Text('${context.t('confidence')}: ', style: const TextStyle(fontFamily: 'DMSans', fontSize: 13, color: VNColors.muted)),
                Text('${(analysis.confidence * 100).toInt()}%', style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 16, fontWeight: FontWeight.bold, color: VNColors.cyan)),
              ]),
              const SizedBox(height: 6),
              LinearPercentIndicator(percent: analysis.confidence, lineHeight: 6, progressColor: VNColors.cyan, backgroundColor: VNColors.bgCard2, barRadius: const Radius.circular(3), padding: EdgeInsets.zero),
              const SizedBox(height: 14),

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
              const SizedBox(height: 14),

              // Complaint letter
              if (analysis.complaintLetter.isNotEmpty)
                ComplaintLetterWidget(letter: analysis.complaintLetter),
            ],
            const SizedBox(height: 40),
          ])),
        ]),
      ),
    );
  }
}
