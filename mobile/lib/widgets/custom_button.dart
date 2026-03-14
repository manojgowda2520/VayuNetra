import 'package:flutter/material.dart';
import '../config/theme.dart';

class VNButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final bool outlined;
  final IconData? icon;
  final Color? color;
  final double? width;

  const VNButton({super.key, required this.label, this.onTap,
    this.loading = false, this.outlined = false, this.icon, this.color, this.width});

  @override
  Widget build(BuildContext context) {
    final c = color ?? VNColors.saffron;
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: width ?? double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          gradient: outlined ? null : LinearGradient(
            colors: [c, VNColors.cyan], begin: Alignment.centerLeft, end: Alignment.centerRight),
          border: outlined ? Border.all(color: c, width: 1.5) : null,
          borderRadius: BorderRadius.circular(12),
          color: outlined ? Colors.transparent : null,
        ),
        child: loading
            ? const Center(child: SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[Icon(icon, color: outlined ? c : Colors.white, size: 18), const SizedBox(width: 8)],
                  Text(label, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.bold,
                    fontSize: 16, color: outlined ? c : Colors.white, letterSpacing: 0.5)),
                ],
              ),
      ),
    );
  }
}
