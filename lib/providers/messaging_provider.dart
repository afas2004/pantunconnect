import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/chat_model.dart';
import '../models/user_model.dart';
import '../repositories/chat_repository.dart';
import '../repositories/user_repository.dart';

/// Mirrors ui/screens/chat/MessagingViewModel.kt: streams messages for a single chat and lets
/// the current user send new ones. Also resolves the other participant's profile so the app bar
/// can show their real name/avatar instead of a bare chat id.
class MessagingProvider extends ChangeNotifier {
  MessagingProvider(this._chatRepository, this._userRepository, this._auth, this.chatId) {
    _init();
  }

  final ChatRepository _chatRepository;
  final UserRepository _userRepository;
  final FirebaseAuth _auth;
  final String chatId;

  List<ChatMessage> messages = [];
  AppUser? otherUser;
  bool isSending = false;
  String? error;

  StreamSubscription<List<ChatMessage>>? _sub;

  String? get currentUserId => _auth.currentUser?.uid;

  Future<void> _init() async {
    _sub = _chatRepository.getMessages(chatId).listen((value) {
      messages = value;
      notifyListeners();
    });

    // Resolve the other participant's profile for the app bar, by reading the chat doc once
    // via getChats (cheap enough for a single lookup here) - simplest approach without adding a
    // dedicated getChat(id) method to the repository.
    final userId = currentUserId;
    if (userId == null) return;
    final chats = await _chatRepository.getChats(userId).first;
    final chat = chats.where((c) => c.id == chatId).cast<Chat?>().firstWhere((c) => c != null, orElse: () => null);
    final otherId = chat?.otherParticipantId(userId);
    if (otherId != null) {
      otherUser = await _userRepository.getUser(otherId);
      notifyListeners();
    }
  }

  Future<void> sendMessage(String text) async {
    final userId = currentUserId;
    if (userId == null || text.trim().isEmpty) return;
    isSending = true;
    error = null; // clear any previous failure so it isn't mistaken for this attempt's result
    notifyListeners();
    try {
      final message = ChatMessage(chatId: chatId, senderId: userId, text: text.trim());
      await _chatRepository.sendMessage(chatId, message);
    } catch (e) {
      error = e.toString();
    }
    isSending = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
