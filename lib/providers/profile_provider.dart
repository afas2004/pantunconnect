import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/post_model.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/post_repository.dart';
import '../repositories/user_repository.dart';

/// Mirrors ui/screens/profile/ProfileViewModel.kt.
class ProfileProvider extends ChangeNotifier {
  ProfileProvider(this._userRepository, this._postRepository, this._authRepository, this._auth) {
    _loadProfile();
  }

  final UserRepository _userRepository;
  final PostRepository _postRepository;
  final AuthRepository _authRepository;
  final FirebaseAuth _auth;

  AppUser? user;
  List<Post> userPosts = [];
  // True post count for the "Pantun" stat - NOT userPosts.length, which is capped at 100 by
  // getPostsByUser and was showing "100" on accounts (like the seed curator) with thousands more.
  int userPostsCount = 0;
  bool isLoading = false;
  String? error;

  Future<void> _loadProfile() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    isLoading = true;
    notifyListeners();
    try {
      user = await _userRepository.getUser(currentUser.uid);
      final results = await Future.wait([
        _postRepository.getPostsByUser(currentUser.uid),
        _postRepository.getPostCountByUser(currentUser.uid),
      ]);
      userPosts = results[0] as List<Post>;
      userPostsCount = results[1] as int;
    } catch (e) {
      error = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() => _loadProfile();

  Future<void> logout() async {
    await _authRepository.logout();
  }
}
