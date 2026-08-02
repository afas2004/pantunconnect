import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../repositories/chat_repository.dart';
import '../repositories/user_repository.dart';

/// Mirrors ui/screens/connections/UserConnectionsViewModel.kt (the Followers/Following screen
/// that was entirely missing before - ProfileScreen only showed follower/following COUNTS, with
/// no way to see who they actually were or message them).
class UserConnectionsProvider extends ChangeNotifier {
  UserConnectionsProvider(this._userRepository, this._chatRepository, this._auth);

  final UserRepository _userRepository;
  final ChatRepository _chatRepository;
  final FirebaseAuth _auth;

  List<AppUser> followers = [];
  List<AppUser> following = [];
  bool isLoading = false;
  String? error;

  String? _loadedForUserId;

  Future<void> load(String userId) async {
    if (userId.isEmpty || _loadedForUserId == userId) return;
    _loadedForUserId = userId;

    isLoading = true;
    error = null;
    notifyListeners();
    try {
      followers = await _userRepository.getFollowers(userId);
      following = await _userRepository.getFollowing(userId);
    } catch (e) {
      error = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> startChat(String otherUserId, void Function(String chatId) onChatReady) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;
    try {
      final chatId = await _chatRepository.getOrCreateChat(currentUserId, otherUserId);
      onChatReady(chatId);
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }
}
