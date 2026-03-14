import 'package:flutter/material.dart';
import '../config/theme.dart';

class SeverityBadge extends StatelessWidget {
  final String severity;
  final bool small;
  const SeverityBadge({super.key, required this.severity, this.small = false});

  @override
  Widget build(BuildContext context) {
    final color = severityColor(severity);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 12, vertical: small ? 3 : 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 6)],
      ),
      child: Text(severity.toUpperCase(),
        style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.bold,
          fontSize: small ? 11 : 13, color: color, letterSpacing: 0.5)),
    );
  }
}
