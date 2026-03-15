import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../config/theme.dart';
import '../providers/language_provider.dart';

class VNLoadingWidget extends StatelessWidget {
  final String? message;
  const VNLoadingWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Pulse(
        infinite: true,
        child: Image.asset('assets/images/logo.png', width: 80, height: 80, fit: BoxFit.contain),
      ),
      const SizedBox(height: 16),
      Text(message ?? context.t('loading'), style: const TextStyle(fontFamily: 'DMSans', color: VNColors.muted, fontSize: 14)),
      const SizedBox(height: 12),
      SizedBox(width: 120, child: LinearProgressIndicator(color: VNColors.cyan, backgroundColor: VNColors.bgCard2, minHeight: 2)),
    ]),
  );
}
