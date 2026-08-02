import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/post_model.dart';
import '../repositories/post_repository.dart';
import '../repositories/user_repository.dart';

/// Mirrors ui/screens/home/HomeViewModel.kt - the home feed dashboard's data source.
/// Uses simple cursor-based pagination (see PostRepository.getFeedPage) as the idiomatic
/// Flutter equivalent of the Kotlin app's Room+Paging3 feed. Also filters out posts from
/// blocked users ("Block User" in the Kotlin PostCard dropdown was a no-op).
class HomeProvider extends ChangeNotifier {
  HomeProvider(this._postRepository, this._userRepository, this._auth) {
    loadInitial();
  }

  final PostRepository _postRepository;
  final UserRepository _userRepository;
  final FirebaseAuth _auth;

  Set<String> _blockedIds = {};

  List<Post> posts = [];

  /// "Trending Now": a random sample of real pantun, refreshed on every feed load/refresh.
  List<Post> trending = [];
  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasMore = true;
  String? error;
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;

  Future<void> loadInitial() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        _blockedIds = await _userRepository.getBlockedUserIds(userId);
      }
      final (page, lastDoc) = await _postRepository.getFeedPage();
      posts = page.where((p) => !_blockedIds.contains(p.authorId)).toList();
      _lastDoc = lastDoc;
      hasMore = page.isNotEmpty;

      // Random sample for Trending Now, drawn from a wider window than the visible feed.
      final pool = (await _postRepository.getRecentPosts(limit: 30))
          .where((p) => !_blockedIds.contains(p.authorId) && p.content.trim().isNotEmpty)
          .toList()
        ..shuffle();
      trending = pool.take(5).toList();
    } catch (e) {
      error = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (isLoadingMore || !hasMore) return;
    isLoadingMore = true;
    notifyListeners();
    try {
      final (page, lastDoc) = await _postRepository.getFeedPage(startAfter: _lastDoc);
      posts = [...posts, ...page.where((p) => !_blockedIds.contains(p.authorId))];
      _lastDoc = lastDoc;
      hasMore = page.isNotEmpty;
    } catch (e) {
      error = e.toString();
    }
    isLoadingMore = false;
    notifyListeners();
  }

  /// "Block User" from a post's dropdown: records the block and hides their posts immediately.
  Future<void> blockUser(String targetUserId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || targetUserId.isEmpty || targetUserId == userId) return;
    try {
      await _userRepository.blockUser(userId, targetUserId);
      _blockedIds = {..._blockedIds, targetUserId};
      posts = posts.where((p) => !_blockedIds.contains(p.authorId)).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refresh() => loadInitial();

  /// Post ids with a like/unlike request currently in flight - guards against the bug where
  /// mashing the heart button fired a new increment on every tap with nothing to stop it.
  /// While a toggle is pending for a post, further taps on it are ignored until it resolves.
  final Set<String> _pendingLikeIds = {};

  Future<void> toggleLike(String postId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || _pendingLikeIds.contains(postId)) return;
    final index = posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;
    final original = posts[index];

    _pendingLikeIds.add(postId);
    // Optimistic flip so the UI responds instantly; reconciled/reverted once the server replies.
    final optimistic = original.copyWith(
      isLiked: !original.isLiked,
      likesCount: original.likesCount + (original.isLiked ? -1 : 1),
    );
    posts = [for (final p in posts) p.id == postId ? optimistic : p];
    notifyListeners();

    try {
      final liked = await _postRepository.toggleLike(postId, userId);
      if (liked != optimistic.isLiked) {
        // Server disagreed with our guess (e.g. state drifted) - snap to what it reports.
        posts = [
          for (final p in posts)
            p.id == postId ? original.copyWith(isLiked: liked, likesCount: original.likesCount + (liked ? 1 : 0)) : p,
        ];
        notifyListeners();
      }
    } catch (_) {
      // Revert on failure so the count doesn't drift from Firestore.
      posts = [for (final p in posts) p.id == postId ? original : p];
      notifyListeners();
    } finally {
      _pendingLikeIds.remove(postId);
    }
  }

  /// Mirrors HomeViewModel.reportPost - the "Report Post" dropdown item always uses the
  /// default reason "Spam".
  Future<void> reportPost(String postId, {String reason = 'Spam'}) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    try {
      await _postRepository.reportPost(postId, userId, reason);
    } catch (_) {
      // Handle error
    }
  }
}
