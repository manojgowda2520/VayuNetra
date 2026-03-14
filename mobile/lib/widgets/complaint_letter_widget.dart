import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../config/theme.dart';
import '../providers/language_provider.dart';

class ComplaintLetterWidget extends StatelessWidget {
  final String letter;
  const ComplaintLetterWidget({super.key, required this.letter});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: VNColors.bgCard, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VNColors.saffron.withOpacity(0.4)),
      ),
      child: ExpansionTile(
        leading: const Icon(Icons.description, color: VNColors.saffron),
        title: Text(context.t('complaintLetter'),
          style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.bold, fontSize: 15, color: VNColors.saffron)),
        children: [Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: VNColors.bgCard2, borderRadius: BorderRadius.circular(8)),
              child: Text(letter, style: const TextStyle(fontFamily: 'Courier', fontSize: 12, color: VNColors.text, height: 1.6)),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () { Clipboard.setData(ClipboardData(text: letter));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t('letterCopied')))); },
                icon: const Icon(Icons.copy, size: 16), label: Text(context.t('copy')),
                style: OutlinedButton.styleFrom(foregroundColor: VNColors.cyan, side: const BorderSide(color: VNColors.cyan)),
              )),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(
                onPressed: () => Share.share(letter),
                icon: const Icon(Icons.share, size: 16), label: Text(context.t('share')),
                style: OutlinedButton.styleFrom(foregroundColor: VNColors.saffron, side: const BorderSide(color: VNColors.saffron)),
              )),
            ]),
          ]),
        )],
      ),
    );
  }
}
