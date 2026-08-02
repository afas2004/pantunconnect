import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/comment_model.dart';
import '../models/post_model.dart';
import '../repositories/post_repository.dart';

/// Mirrors ui/screens/post_detail/PostDetailViewModel.kt.
class PostDetailProvider extends ChangeNotifier {
  PostDetailProvider(this._postRepository, this._auth, this.postId) {
    _load();
  }

  final PostRepository _postRepository;
  final FirebaseAuth _auth;
  final String postId;

  Post? post;
  List<Comment> comments = [];
  bool isLoading = false;
  bool isSubmittingComment = false;
  String? error;

  Future<void> _load() async {
    isLoading = true;
    notifyListeners();
    try {
      post = await _postRepository.getPostById(postId);
      comments = await _postRepository.getComments(postId);
    } catch (e) {
      error = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() => _load();

  bool _isTogglingLike = false;

  /// Same fix as HomeProvider.toggleLike: the old likePost() always incremented likesCount by 1
  /// with no record of whether this user had already liked the post, so repeated taps on the
  /// heart button pushed the count up without limit. This checks the server-confirmed like state
  /// via PostRepository.toggleLike (transactional, keyed off posts/{id}/likes/{userId}) and
  /// ignores taps while a request is already in flight.
  Future<void> likePost() async {
    final userId = _auth.currentUser?.uid;
    final current = post;
    if (userId == null || current == null || _isTogglingLike) return;
    _isTogglingLike = true;

    final optimistic = current.copyWith(
      isLiked: !current.isLiked,
      likesCount: current.likesCount + (current.isLiked ? -1 : 1),
    );
    post = optimistic;
    notifyListeners();

    try {
      final liked = await _postRepository.toggleLike(postId, userId);
      if (liked != optimistic.isLiked) {
        post = current.copyWith(isLiked: liked, likesCount: current.likesCount + (liked ? 1 : 0));
        notifyListeners();
      }
    } catch (_) {
      post = current;
      notifyListeners();
    } finally {
      _isTogglingLike = false;
    }
  }

  Future<void> addComment(String text) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || text.trim().isEmpty) return;
    isSubmittingComment = true;
    notifyListeners();
    try {
      final comment = Comment(
        authorId: currentUser.uid,
        authorName: currentUser.displayName ?? 'Anonymous',
        text: text.trim(),
      );
      await _postRepository.addComment(postId, comment);
      comments = await _postRepository.getComments(postId);
      final current = post;
      if (current != null) {
        post = Post.fromMap({...current.toMap(), 'commentsCount': current.commentsCount + 1});
      }
    } catch (e) {
      error = e.toString();
    }
    isSubmittingComment = false;
    notifyListeners();
  }

  Future<void> reportPost(String reason) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    await _postRepository.reportPost(postId, userId, reason);
  }
}
