import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/chat_model.dart';
import '../repositories/chat_repository.dart';
import '../repositories/user_repository.dart';

/// Mirrors ui/screens/chat/ChatListViewModel.kt, including the real-username-resolution fix
/// made on the Kotlin side (the chat list used to show a hardcoded "User Name" for everyone).
class ChatListProvider extends ChangeNotifier {
  ChatListProvider(this._chatRepository, this._userRepository, this._auth) {
    _loadChats();
  }

  final ChatRepository _chatRepository;
  final UserRepository _userRepository;
  final FirebaseAuth _auth;

  List<Chat> chats = [];
  Map<String, String> userNames = {};
  bool isLoading = false;
  String? error;

  StreamSubscription<List<Chat>>? _sub;

  String? get currentUserId => _auth.currentUser?.uid;

  void _loadChats() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    isLoading = true;
    notifyListeners();

    _sub = _chatRepository.getChats(userId).listen((value) async {
      chats = value;
      isLoading = false;
      notifyListeners();

      final otherIds = value
          .map((c) => _chatRepository.getOtherParticipantId(c, userId))
          .whereType<String>()
          .toList();
      if (otherIds.isNotEmpty) {
        final users = await _userRepository.getUsers(otherIds);
        userNames = {for (final u in users) u.id: u.username};
        notifyListeners();
      }
    }, onError: (e) {
      error = e.toString();
      isLoading = false;
      notifyListeners();
    });
  }

  String displayNameFor(Chat chat) {
    final otherId = chat.otherParticipantId(currentUserId ?? '');
    final name = otherId != null ? userNames[otherId] : null;
    return (name != null && name.isNotEmpty) ? name : 'User';
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
