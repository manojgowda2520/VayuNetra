import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../config/theme.dart';

class AQIGauge extends StatelessWidget {
  final int aqi;
  final double radius;
  const AQIGauge({super.key, required this.aqi, this.radius = 40});

  Color get _color {
    if (aqi <= 50)  return VNColors.green;
    if (aqi <= 100) return VNColors.yellow;
    if (aqi <= 200) return VNColors.orange;
    return VNColors.red;
  }

  @override
  Widget build(BuildContext context) => CircularPercentIndicator(
    radius: radius, lineWidth: 7,
    percent: (aqi / 300).clamp(0.0, 1.0),
    center: Text('$aqi', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.bold,
      fontSize: radius * 0.5, color: _color)),
    progressColor: _color,
    backgroundColor: VNColors.bgCard2,
    circularStrokeCap: CircularStrokeCap.round,
  );
}
