import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/post_model.dart';
import '../models/user_model.dart';
import '../repositories/post_repository.dart';
import '../repositories/user_repository.dart';

/// Mirrors ui/screens/search/SearchViewModel.kt, including the 500ms debounce behavior.
///
/// The search bar's hint text ("Search hashtags, users, or keywords...") promised user search
/// that was never actually implemented - this only ever queried posts. Now searches posts and
/// users in parallel; see UserRepository.searchUsers for how the user side works (and its
/// limits - Firestore text search is prefix-only and case-sensitive).
class SearchProvider extends ChangeNotifier {
  SearchProvider(this._postRepository, this._userRepository);

  final PostRepository _postRepository;
  final UserRepository _userRepository;

  String query = '';
  List<Post> results = [];
  List<AppUser> userResults = [];
  bool isLoading = false;
  String? error;

  Timer? _debounce;

  void onQueryChange(String newQuery) {
    query = newQuery;
    notifyListeners();

    _debounce?.cancel();
    if (newQuery.length < 2 && !newQuery.startsWith('#')) {
      results = [];
      userResults = [];
      notifyListeners();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () => _performSearch(newQuery));
  }

  Future<void> _performSearch(String q) async {
    isLoading = true;
    notifyListeners();
    try {
      final combined = await Future.wait([
        _postRepository.searchPosts(q),
        _userRepository.searchUsers(q),
      ]);
      results = combined[0] as List<Post>;
      userResults = combined[1] as List<AppUser>;
    } catch (e) {
      error = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
