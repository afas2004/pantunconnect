import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/post_model.dart';
import '../models/user_model.dart';
import '../repositories/chat_repository.dart';
import '../repositories/post_repository.dart';
import '../repositories/user_repository.dart';

/// Backs the OTHER-user profile screen (the missing half of the follow mechanism - the Profile
/// tab only ever shows the signed-in user, so before this there was nowhere to put a Follow
/// button). Loads the viewed user's profile + pantun, tracks follow state, and can start a chat.
class UserProfileProvider extends ChangeNotifier {
  UserProfileProvider(
    this._userRepository,
    this._postRepository,
    this._chatRepository,
    this._auth,
    this.userId,
  ) {
    _load();
  }

  final UserRepository _userRepository;
  final PostRepository _postRepository;
  final ChatRepository _chatRepository;
  final FirebaseAuth _auth;

  /// The user being viewed (not necessarily the signed-in user).
  final String userId;

  AppUser? user;
  List<Post> posts = [];
  // True post count for the "Pantun" stat - posts.length is capped at 100 by getPostsByUser and
  // undercounts any account with more than that (e.g. the seed curator's ~5,642 posts).
  int postsCount = 0;
  bool isLoading = false;
  bool isFollowing = false;
  bool isFollowBusy = false;
  String? error;

  bool get isSelf => _auth.currentUser?.uid == userId;

  Future<void> _load() async {
    isLoading = true;
    notifyListeners();
    try {
      user = await _userRepository.getUser(userId);
      final results = await Future.wait([
        _postRepository.getPostsByUser(userId),
        _postRepository.getPostCountByUser(userId),
      ]);
      posts = results[0] as List<Post>;
      postsCount = results[1] as int;
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId != null && !isSelf) {
        isFollowing = await _userRepository.isFollowing(currentUserId, userId);
      }
    } catch (e) {
      error = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() => _load();

  Future<void> toggleFollow() async {
    final currentUserId = _auth.currentUser?.uid;
    final current = user;
    if (currentUserId == null || isSelf || isFollowBusy || current == null) return;

    isFollowBusy = true;
    notifyListeners();
    try {
      if (isFollowing) {
        await _userRepository.unfollowUser(currentUserId, userId);
        isFollowing = false;
        user = current.copyWith(followersCount: current.followersCount - 1);
      } else {
        await _userRepository.followUser(currentUserId, userId);
        isFollowing = true;
        user = current.copyWith(followersCount: current.followersCount + 1);
      }
    } catch (e) {
      error = e.toString();
    }
    isFollowBusy = false;
    notifyListeners();
  }

  Future<void> startChat(void Function(String chatId) onNavigateToChat) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null || isSelf) return;
    try {
      final chatId = await _chatRepository.getOrCreateChat(currentUserId, userId);
      onNavigateToChat(chatId);
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }
}
