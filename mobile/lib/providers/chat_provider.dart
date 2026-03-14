import 'package:flutter/material.dart';
import 'dart:async';
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
  bool _loading = false;

  List<ChatMessage> get messages => _messages;
  bool get loading => _loading;

  Future<void> sendMessage(String text) async {
    _messages.add(ChatMessage(role: 'user', content: text));
    _loading = true; notifyListeners();
    try {
      final history = _messages
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();
      final res = await ApiService.chat(text, history.cast<Map<String, String>>())
          .timeout(const Duration(milliseconds: 1200));
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

  void clear() { _messages.clear(); notifyListeners(); }
}
