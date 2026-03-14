import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/report.dart';
import '../config/theme.dart';
import 'severity_badge.dart';
import 'glass_card.dart';

class ReportCard extends StatelessWidget {
  final Report report;
  final VoidCallback? onTap;
  const ReportCard({super.key, required this.report, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      borderRadius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
              child: report.photoUrl != null
                  ? CachedNetworkImage(imageUrl: report.photoUrl!, height: 130, width: double.infinity, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _placeholder())
                  : _placeholder(),
            ),
            if (report.analysis != null)
              Positioned(top: 8, right: 8, child: SeverityBadge(severity: report.analysis!.severity, small: true)),
          ]),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(report.area, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.bold, fontSize: 14, color: VNColors.text), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(timeago.format(report.createdAt), style: const TextStyle(fontSize: 11, color: VNColors.muted, fontFamily: 'DMSans')),
              if (report.analysis != null)
                Text(report.analysis!.pollutionType, style: const TextStyle(fontSize: 11, color: VNColors.cyan, fontFamily: 'DMSans')),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(height: 130, width: double.infinity, color: VNColors.bgCard2,
      child: const Icon(Icons.image_not_supported, color: VNColors.muted, size: 40));
}
