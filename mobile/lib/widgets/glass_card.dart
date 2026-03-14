import 'package:flutter/material.dart';
import '../config/theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double borderRadius;

  const GlassCard({super.key, required this.child, this.padding, this.onTap, this.borderRadius = 16});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VNColors.bgCard,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: VNColors.border),
        boxShadow: [BoxShadow(color: VNColors.cyan.withOpacity(0.06), blurRadius: 12)],
      ),
      child: child,
    ),
  );
}
