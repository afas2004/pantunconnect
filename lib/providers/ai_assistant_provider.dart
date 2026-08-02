import 'package:flutter/foundation.dart';

import '../services/gemini_service.dart';

class AiChatMessage {
  final String text;
  final bool isUser;
  final bool isError;

  const AiChatMessage({required this.text, required this.isUser, this.isError = false});

  AiChatMessage copyWith({String? text}) => AiChatMessage(text: text ?? this.text, isUser: isUser, isError: isError);
}

/// Mirrors ui/screens/ai/AiAssistantViewModel.kt.
class AiAssistantProvider extends ChangeNotifier {
  AiAssistantProvider(this._geminiService);

  final GeminiService _geminiService;

  List<AiChatMessage> messages = [];
  bool isLoading = false;

  Future<void> sendMessage(String prompt) async {
    if (prompt.trim().isEmpty) return;

    messages = [...messages, AiChatMessage(text: prompt, isUser: true)];
    isLoading = true;
    notifyListeners();

    try {
      var aiResponse = '';
      await for (final chunk in _geminiService.generateContent(prompt)) {
        aiResponse += chunk;
        final last = messages.isNotEmpty ? messages.last : null;
        if (last != null && !last.isUser && !last.isError) {
          messages = [...messages.sublist(0, messages.length - 1), AiChatMessage(text: aiResponse, isUser: false)];
        } else {
          messages = [...messages, AiChatMessage(text: aiResponse, isUser: false)];
        }
        notifyListeners();
      }
    } catch (e) {
      messages = [...messages, AiChatMessage(text: 'Maaf, ralat berlaku: $e', isUser: false, isError: true)];
    }

    isLoading = false;
    notifyListeners();
  }

  void clearChat() {
    messages = [];
    notifyListeners();
  }
}
