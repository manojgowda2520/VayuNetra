import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../services/api_service.dart';

class ChatMessage {
  final String role;
  final String content;
  final List<String> toolsUsed;
  final DateTime time;

  ChatMessage({required this.role, required this.content,
    this.toolsUsed = const [], DateTime? time}) : time = time ?? DateTime.now();
}

class ChatProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  final AudioRecorder _recorder = AudioRecorder();
  bool _loading = false;
  bool _voiceMode = false;
  bool _recording = false;
  bool _transcribing = false;

  List<ChatMessage> get messages => _messages;
  bool get loading => _loading;
  bool get voiceMode => _voiceMode;
  bool get recording => _recording;
  bool get transcribing => _transcribing;

  void toggleVoiceMode() {
    _voiceMode = !_voiceMode;
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    _messages.add(ChatMessage(role: 'user', content: text));
    _loading = true; notifyListeners();
    try {
      final history = _messages
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();
      final res = await ApiService.chat(text, history.cast<Map<String, String>>())
          .timeout(const Duration(seconds: 30));
      final reply = res['response'] ?? res['message'] ?? 'No response';
      final tools = List<String>.from(res['tools_used'] ?? []);
      _messages.add(ChatMessage(role: 'assistant', content: reply, toolsUsed: tools));
    } catch (_) {
      _messages.add(ChatMessage(
        role: 'assistant',
        content: 'I am running in local demo mode right now. Once the backend is ready, I can answer live Bengaluru air-quality questions here.',
        toolsUsed: const ['demo-mode'],
      ));
    }
    _loading = false; notifyListeners();
  }

  Future<bool> startRecording() async {
    if (!await _recorder.hasPermission()) return false;
    final tempDir = await getTemporaryDirectory();
    final path = '${tempDir.path}/vayunetra-chat-${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    _recording = true;
    notifyListeners();
    return true;
  }

  Future<bool> stopRecordingAndSend(String languageCode) async {
    if (!_recording) return false;
    _recording = false;
    _transcribing = true;
    notifyListeners();

    final path = await _recorder.stop();
    if (path == null) {
      _transcribing = false;
      notifyListeners();
      return false;
    }

    try {
      final res = await ApiService.transcribeVoice(path, languageCode)
          .timeout(const Duration(seconds: 20));
      final transcript = (res['transcription'] ?? '').toString().trim();
      _transcribing = false;
      notifyListeners();
      if (transcript.isEmpty) return false;
      await sendMessage(transcript);
      return true;
    } catch (_) {
      _transcribing = false;
      notifyListeners();
      return false;
    } finally {
      unawaited(File(path).delete().catchError((_) {}));
    }
  }

  Future<void> cancelRecording() async {
    if (!_recording) return;
    await _recorder.stop();
    _recording = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  void clear() { _messages.clear(); notifyListeners(); }
}
