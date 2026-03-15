import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/language_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  void _send([String? text]) async {
    final msg = text ?? _ctrl.text.trim();
    if (msg.isEmpty) return;
    _ctrl.clear();
    await context.read<ChatProvider>().sendMessage(msg);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  Future<void> _handleVoiceTap() async {
    final chat = context.read<ChatProvider>();
    final languageCode = context.read<LanguageProvider>().languageCode;
    final messenger = ScaffoldMessenger.of(context);

    if (!chat.recording) {
      final ok = await chat.startRecording();
      if (!ok && mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.t('microphoneDenied'))),
        );
      }
      return;
    }

    final sent = await chat.stopRecordingAndSend(languageCode);
    if (!sent && mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.t('voiceTranscriptFailed'))),
      );
    }
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prompts = [
      context.t('cleanAirAreasToday'),
      context.t('worstPollutionAreas'),
      context.t('safeForJogging'),
      context.t('showStats'),
      context.t('howToComplaint'),
    ];
    final chat = context.watch<ChatProvider>();
    final statusText = chat.transcribing
        ? context.t('transcribingVoice')
        : chat.recording
            ? context.t('voiceRecording')
            : chat.voiceMode
                ? context.t('tapMicToSpeak')
                : null;
    return Scaffold(
      backgroundColor: VNColors.bg,
      appBar: AppBar(
        backgroundColor: VNColors.bg,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.t('aiAgent'), style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 20, color: VNColors.text)),
          Text(context.t('poweredByNova'), style: const TextStyle(fontFamily: 'DMSans', fontSize: 11, color: VNColors.muted)),
        ]),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: VNColors.text), onPressed: () => Navigator.pop(context)),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: VNColors.muted),
          onPressed: () => context.read<ChatProvider>().clear())],
      ),
      body: Column(children: [
        Expanded(child: Consumer<ChatProvider>(builder: (_, chat, __) {
          if (chat.messages.isEmpty) return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.visibility, color: VNColors.cyan, size: 48),
            const SizedBox(height: 12),
            Text(context.t('askAirQuality'), style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 18, color: VNColors.text)),
            const SizedBox(height: 24),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(spacing: 8, runSpacing: 8,
                children: prompts.map((p) => GestureDetector(onTap: () => _send(p),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: VNColors.bgCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: VNColors.border)),
                    child: Text(p, style: const TextStyle(fontFamily: 'DMSans', fontSize: 13, color: VNColors.text))))).toList())),
          ]);

          return ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: chat.messages.length + (chat.loading ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == chat.messages.length) return Padding(
                padding: const EdgeInsets.only(left: 52, top: 6),
                child: Row(children: List.generate(3, (j) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _Dot(delay: j * 200)))));
              final m = chat.messages[i];
              return ChatBubble(message: m.content, isUser: m.role == 'user', toolsUsed: m.toolsUsed);
            });
        })),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(color: VNColors.bgCard, border: Border(top: BorderSide(color: VNColors.border))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (statusText != null) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 12,
                      color: chat.recording ? VNColors.red : VNColors.cyan,
                    ),
                  ),
                ),
              ],
              Row(children: [
                GestureDetector(
                  onTap: chat.transcribing ? null : () => context.read<ChatProvider>().toggleVoiceMode(),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: chat.voiceMode ? VNColors.saffron : VNColors.bgCard2,
                      border: Border.all(color: chat.voiceMode ? VNColors.saffron : VNColors.border),
                    ),
                    child: Icon(
                      chat.voiceMode ? Icons.keyboard_alt_rounded : Icons.mic_none_rounded,
                      color: chat.voiceMode ? Colors.black : VNColors.text,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  controller: _ctrl,
                  readOnly: chat.voiceMode,
                  enabled: !chat.transcribing,
                  style: const TextStyle(color: VNColors.text, fontFamily: 'DMSans'),
                  onSubmitted: chat.voiceMode ? null : (_) => _send(),
                  decoration: InputDecoration(
                    hintText: chat.voiceMode ? context.t('tapMicToSpeak') : context.t('askAboutAir'),
                    hintStyle: const TextStyle(color: VNColors.muted, fontFamily: 'DMSans', fontSize: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: VNColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: VNColors.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: VNColors.cyan)),
                    filled: true, fillColor: VNColors.bgCard2,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)))),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: chat.transcribing || chat.loading
                      ? null
                      : chat.voiceMode
                          ? _handleVoiceTap
                          : _send,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: chat.voiceMode
                          ? (chat.recording ? VNColors.red : VNColors.saffron)
                          : VNColors.cyan,
                    ),
                    child: Icon(
                      chat.voiceMode
                          ? (chat.recording ? Icons.stop_rounded : Icons.mic_rounded)
                          : Icons.send_rounded,
                      color: Colors.black,
                      size: 20,
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay; const _Dot({required this.delay});
  @override State<_Dot> createState() => _DotState();
}
class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;
  @override void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600)); _a = Tween<double>(begin: 0, end: -8).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)); Future.delayed(Duration(milliseconds: widget.delay), () { if (mounted) _c.repeat(reverse: true); }); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _a, builder: (_, __) => Transform.translate(offset: Offset(0, _a.value), child: Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: VNColors.cyan))));
}
