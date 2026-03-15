import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../config/theme.dart';
import '../config/constants.dart';
import '../models/report.dart';
import '../providers/auth_provider.dart';
import '../providers/report_provider.dart';
import '../widgets/severity_badge.dart';
import '../widgets/complaint_letter_widget.dart';
import '../services/api_service.dart';
import 'package:timeago/timeago.dart' as timeago;

class ReportDetailScreen extends StatefulWidget {
  const ReportDetailScreen({super.key});
  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  bool _filingComplaint = false;
  String? _filedRef;
  String? _filedMsg;

  Future<void> _autoFileComplaint(int reportId) async {
    setState(() {
      _filingComplaint = true;
      _filedRef = null;
      _filedMsg = null;
    });
    try {
      final result = await ApiService.fileComplaintViaNovaAct(reportId);
      setState(() {
        _filingComplaint = false;
        _filedRef = result['reference_number'] as String? ?? 'Filed';
        _filedMsg = result['message'] as String? ?? '';
      });
    } catch (e) {
      setState(() {
        _filingComplaint = false;
        _filedMsg = 'Error: $e';
      });
    }
  }

  Color _sevColor(String s) {
    switch (s.toUpperCase()) {
      case 'CRITICAL': return VNColors.red;
      case 'HIGH':     return VNColors.orange;
      case 'MODERATE': return VNColors.yellow;
      default:         return VNColors.green;
    }
  }

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
        title: Text(report.area,
            style: const TextStyle(
                fontFamily: 'Rajdhani', fontSize: 18, color: VNColors.text)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: VNColors.text),
            onPressed: () => Navigator.pop(context)),
        actions: [
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: VNColors.red),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: VNColors.bgCard,
                    title: const Text('Delete Report?',
                        style: TextStyle(
                            fontFamily: 'Rajdhani', color: VNColors.text)),
                    content: const Text('This cannot be undone.',
                        style: TextStyle(
                            fontFamily: 'DMSans', color: VNColors.muted)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel',
                              style: TextStyle(color: VNColors.muted))),
                      TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete',
                              style: TextStyle(color: VNColors.red))),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
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
              height: 240,
              width: double.infinity,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                  height: 240,
                  color: VNColors.bgCard2,
                  child: const Icon(Icons.image,
                      color: VNColors.muted, size: 80)),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header
              Row(children: [
                Expanded(
                    child: Text(report.area,
                        style: const TextStyle(
                            fontFamily: 'Rajdhani',
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: VNColors.text))),
                if (analysis != null)
                  SeverityBadge(severity: analysis.severity),
              ]),
              const SizedBox(height: 4),
              Text(timeago.format(report.createdAt),
                  style: const TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 12,
                      color: VNColors.muted)),
              Text(
                  '${report.latitude.toStringAsFixed(4)}, ${report.longitude.toStringAsFixed(4)}',
                  style: const TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 11,
                      color: VNColors.muted)),

              if (analysis != null) ...[
                const SizedBox(height: 16),

                // Nova badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: VNColors.cyan.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: VNColors.border),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.auto_awesome, color: VNColors.cyan, size: 14),
                    SizedBox(width: 4),
                    Text('Analyzed by Amazon Nova 2 Lite',
                        style: TextStyle(
                            fontFamily: 'DMSans',
                            fontSize: 11,
                            color: VNColors.cyan)),
                  ]),
                ),
                const SizedBox(height: 12),

                // Pollution Report — AQI levels
                Text('POLLUTION REPORT',
                    style: TextStyle(
                        fontFamily: 'Rajdhani',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: VNColors.muted)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: VNColors.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: VNColors.border),
                  ),
                  child: Row(children: [
                    Icon(Icons.air, color: _sevColor(analysis.severity), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Estimated AQI impact',
                                style: const TextStyle(
                                    fontFamily: 'DMSans',
                                    fontSize: 12,
                                    color: VNColors.muted)),
                            Text(analysis.estimatedAqiImpact,
                                style: TextStyle(
                                    fontFamily: 'Rajdhani',
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _sevColor(analysis.severity))),
                            const SizedBox(height: 2),
                            Text('AQI range: ${analysis.estimatedAqiRange}',
                                style: const TextStyle(
                                    fontFamily: 'DMSans',
                                    fontSize: 12,
                                    color: VNColors.text)),
                          ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),

                // Pollution type
                Text(analysis.pollutionType,
                    style: const TextStyle(
                        fontFamily: 'Rajdhani',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: VNColors.cyan)),
                const SizedBox(height: 8),

                // Health risk
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: VNColors.yellow.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: VNColors.yellow.withOpacity(0.4)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.health_and_safety_outlined,
                        color: VNColors.yellow, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(analysis.healthRisk,
                            style: const TextStyle(
                                fontFamily: 'DMSans',
                                fontSize: 13,
                                color: VNColors.text))),
                  ]),
                ),
                const SizedBox(height: 12),

                Text(analysis.description,
                    style: const TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 14,
                        color: VNColors.text,
                        height: 1.6)),
                const SizedBox(height: 12),

                // Confidence
                Row(children: [
                  const Text('Confidence: ',
                      style: TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: 13,
                          color: VNColors.muted)),
                  Text('${(analysis.confidence * 100).toInt()}%',
                      style: const TextStyle(
                          fontFamily: 'Rajdhani',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: VNColors.cyan)),
                ]),
                const SizedBox(height: 6),
                LinearPercentIndicator(
                  percent: analysis.confidence.clamp(0.0, 1.0),
                  lineHeight: 6,
                  progressColor: VNColors.cyan,
                  backgroundColor: VNColors.bgCard2,
                  barRadius: const Radius.circular(3),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: 16),

                // Recommendations
                if (analysis.recommendations.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: VNColors.bgCard,
                      borderRadius: BorderRadius.circular(12),
                      border: const Border(
                          left: BorderSide(color: VNColors.cyan, width: 3)),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(children: [
                            Icon(Icons.lightbulb_outline,
                                color: VNColors.cyan, size: 18),
                            SizedBox(width: 6),
                            Text('Recommendations',
                                style: TextStyle(
                                    fontFamily: 'Rajdhani',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: VNColors.cyan)),
                          ]),
                          const SizedBox(height: 8),
                          ...analysis.recommendations.map((r) => Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('• $r',
                                    style: const TextStyle(
                                        fontFamily: 'DMSans',
                                        fontSize: 13,
                                        color: VNColors.text)),
                              )),
                        ]),
                  ),
                const SizedBox(height: 16),

                // Complaint letter
                if (analysis.complaintLetter.isNotEmpty) ...[
                  Text('COMPLAINT LETTER',
                      style: TextStyle(
                          fontFamily: 'Rajdhani',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: VNColors.muted)),
                  const SizedBox(height: 8),
                  ComplaintLetterWidget(letter: analysis.complaintLetter),
                  const SizedBox(height: 16),
                ],

                // ── NOVA ACT SECTION ───────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: VNColors.purple.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: VNColors.purple.withOpacity(0.5)),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(children: [
                          Icon(Icons.rocket_launch,
                              color: VNColors.purple, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Nova Act — Auto-File Complaint',
                                      style: TextStyle(
                                          fontFamily: 'Rajdhani',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: VNColors.purple)),
                                  Text(
                                      'UI automation: navigates KSPCB portal automatically',
                                      style: TextStyle(
                                          fontFamily: 'DMSans',
                                          fontSize: 11,
                                          color: VNColors.muted)),
                                ]),
                          ),
                        ]),
                        const SizedBox(height: 12),

                        // Success state
                        if (_filedRef != null)
                          FadeInUp(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: VNColors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color:
                                        VNColors.green.withOpacity(0.5)),
                              ),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('✅ Reference: $_filedRef',
                                        style: const TextStyle(
                                            fontFamily: 'Rajdhani',
                                            fontSize: 15,
                                            color: VNColors.green,
                                            fontWeight: FontWeight.bold)),
                                    if (_filedMsg != null &&
                                        _filedMsg!.isNotEmpty)
                                      Text(_filedMsg!,
                                          style: const TextStyle(
                                              fontFamily: 'DMSans',
                                              fontSize: 12,
                                              color: VNColors.muted)),
                                  ]),
                            ),
                          )
                        else
                          // File button
                          GestureDetector(
                            onTap: _filingComplaint
                                ? null
                                : () => _autoFileComplaint(report.id),
                            child: Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 13),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    VNColors.purple,
                                    Color(0xFF7C3AED)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: _filingComplaint
                                  ? const Center(
                                      child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                          SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2)),
                                          SizedBox(width: 10),
                                          Text(
                                              'Nova Act filing complaint...',
                                              style: TextStyle(
                                                  fontFamily: 'Rajdhani',
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  color: Colors.white)),
                                        ]))
                                  : const Center(
                                      child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                          Icon(Icons.rocket_launch,
                                              color: Colors.white, size: 18),
                                          SizedBox(width: 8),
                                          Text(
                                              'Auto-File with Nova Act',
                                              style: TextStyle(
                                                  fontFamily: 'Rajdhani',
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  fontSize: 16,
                                                  color: Colors.white,
                                                  letterSpacing: 0.5)),
                                        ])),
                            ),
                          ),
                      ]),
                ),
              ],
              const SizedBox(height: 40),
            ]),
          ),
        ]),
      ),
    );
  }
}
