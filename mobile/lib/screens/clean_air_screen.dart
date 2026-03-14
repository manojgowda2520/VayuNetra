import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../providers/language_provider.dart';
import '../models/clean_zone.dart';
import '../widgets/aqi_gauge.dart';
import '../widgets/glass_card.dart';

class CleanAirScreen extends StatelessWidget {
  const CleanAirScreen({super.key});

  Color _color(int aqi) {
    if (aqi <= 50)  return VNColors.green;
    if (aqi <= 100) return VNColors.yellow;
    if (aqi <= 200) return VNColors.orange;
    return VNColors.red;
  }

  String _label(int aqi) {
    if (aqi <= 50)  return 'Excellent';
    if (aqi <= 100) return 'Good';
    if (aqi <= 150) return 'Moderate';
    return 'Unhealthy';
  }

  void _directions(CleanZone z) async {
    final url = Uri.parse('https://maps.google.com/?q=${z.latitude},${z.longitude}');
    if (await canLaunchUrl(url)) launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final zones = CleanZone.fallback;
    return Scaffold(
      backgroundColor: VNColors.bg,
      appBar: AppBar(backgroundColor: VNColors.bg,
        title: Text(context.t('findCleanAir'), style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 20, color: VNColors.text)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: VNColors.text), onPressed: () => Navigator.pop(context))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.t('aqiScale'), style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 13, color: VNColors.muted, letterSpacing: 2)),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(6), child: Row(children: [
            Expanded(child: Container(height: 10, color: VNColors.green)),
            Expanded(child: Container(height: 10, color: VNColors.yellow)),
            Expanded(child: Container(height: 10, color: VNColors.orange)),
            Expanded(child: Container(height: 10, color: VNColors.red)),
          ])),
          const SizedBox(height: 4),
          const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('0-50 Good', style: TextStyle(fontSize: 10, color: VNColors.green, fontFamily: 'DMSans')),
            Text('51-100', style: TextStyle(fontSize: 10, color: VNColors.yellow, fontFamily: 'DMSans')),
            Text('101-200', style: TextStyle(fontSize: 10, color: VNColors.orange, fontFamily: 'DMSans')),
            Text('200+ Bad', style: TextStyle(fontSize: 10, color: VNColors.red, fontFamily: 'DMSans')),
          ]),
        ])),
        const SizedBox(height: 16),
        ...zones.map((z) => Padding(padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(child: Row(children: [
            AQIGauge(aqi: z.aqi, radius: 38),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(z.name, style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 17, fontWeight: FontWeight.bold, color: VNColors.text)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: _color(z.aqi).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: Text(_label(z.aqi), style: TextStyle(fontFamily: 'DMSans', fontSize: 11, color: _color(z.aqi)))),
              const SizedBox(height: 6),
              Wrap(spacing: 4, runSpacing: 4, children: z.activities.map((a) =>
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: VNColors.bgCard2, borderRadius: BorderRadius.circular(6)),
                  child: Text(a, style: const TextStyle(fontFamily: 'DMSans', fontSize: 10, color: VNColors.muted)))).toList()),
              const SizedBox(height: 8),
              GestureDetector(onTap: () => _directions(z),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: VNColors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: VNColors.green.withOpacity(0.5))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.directions, color: VNColors.green, size: 14), const SizedBox(width: 4),
                    Text(context.t('directions'), style: const TextStyle(fontFamily: 'DMSans', fontSize: 12, color: VNColors.green)),
                  ]))),
            ])),
          ])))),
      ]),
    );
  }
}
