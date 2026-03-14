import 'package:flutter/material.dart';
import '../config/theme.dart';

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final List<String> toolsUsed;
  const ChatBubble({super.key, required this.message, required this.isUser, this.toolsUsed = const []});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(width: 32, height: 32,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: VNColors.cyan.withOpacity(0.15), border: Border.all(color: VNColors.cyan)),
                  child: const Icon(Icons.visibility, color: VNColors.cyan, size: 16)),
                const SizedBox(width: 8),
              ],
              Flexible(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isUser ? VNColors.bgCard2 : VNColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border(
                    right: isUser ? const BorderSide(color: VNColors.cyan, width: 3) : BorderSide.none,
                    left:  !isUser ? const BorderSide(color: VNColors.cyan, width: 2) : BorderSide.none,
                  ),
                ),
                child: Text(message, style: const TextStyle(fontFamily: 'DMSans', fontSize: 14, color: VNColors.text)),
              )),
            ],
          ),
          if (toolsUsed.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 4),
              child: Wrap(spacing: 6, children: toolsUsed.map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: VNColors.cyan.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: VNColors.border)),
                child: Text(t, style: const TextStyle(fontSize: 10, color: VNColors.cyan, fontFamily: 'DMSans')),
              )).toList()),
            ),
        ],
      ),
    );
  }
}
