import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/comment_model.dart';
import '../models/post_model.dart';

/// Mirrors data/repository/PostRepository.kt.
///
/// The Kotlin app used Room + Paging3 (PostDao/PostRemoteMediator) as a local cache/pager on top
/// of Firestore, and a backend proxy (PantunApiService) that was never actually deployed (see
/// gemini_service.dart for that whole story). This port talks to Firestore directly and uses
/// simple cursor-based pagination for the feed, which is the idiomatic Flutter equivalent of
/// Paging3 without pulling in a local SQL cache that Flutter Web can't use the same way anyway.
class PostRepository {
  PostRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _posts => _firestore.collection('posts');

  Future<List<Post>> getRecentPosts({int limit = 20}) async {
    try {
      final snapshot = await _posts.orderBy('timestamp', descending: true).limit(limit).get();
      return snapshot.docs.map(Post.fromDoc).toList();
    } catch (_) {
      return [];
    }
  }

  /// Cursor-based pagination for the home feed's infinite scroll.
  Future<(List<Post>, DocumentSnapshot<Map<String, dynamic>>?)> getFeedPage({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 10,
  }) async {
    try {
      var query = _posts.orderBy('timestamp', descending: true).limit(limit);
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }
      final snapshot = await query.get();
      final posts = snapshot.docs.map(Post.fromDoc).toList();
      final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      return (posts, lastDoc);
    } catch (_) {
      return (<Post>[], null);
    }
  }

  Future<void> createPost(Post post) async {
    final docRef = _posts.doc();
    final postWithId = post.copyWith(id: docRef.id);
    await docRef.set(postWithId.toMap());
  }

  Future<Post?> getPostById(String postId) async {
    try {
      final doc = await _posts.doc(postId).get();
      if (!doc.exists) return null;
      return Post.fromDoc(doc);
    } catch (_) {
      return null;
    }
  }

  Future<List<Post>> getPostsByUser(String userId) async {
    try {
      // No orderBy here on purpose: combining a where-equality with orderBy(timestamp) requires
      // a manually-created composite index in Firestore (fails with FAILED_PRECONDITION until
      // someone clicks the index-creation link in the console). Sorting happens client-side.
      //
      // limit(100) guards the read quota: the seed curator account has 5,642 posts, and an
      // uncapped fetch on their profile would cost that many document reads per visit. This caps
      // what's shown in the profile grid - use getPostCountByUser for the "Pantun" stat number,
      // since this list's length is NOT the true count once an account passes 100 posts.
      final snapshot = await _posts.where('authorId', isEqualTo: userId).limit(100).get();
      final posts = snapshot.docs.map(Post.fromDoc).toList();
      posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return posts;
    } catch (_) {
      return [];
    }
  }

  /// True total post count for a user, for the profile stat display. Uses a Firestore
  /// aggregation query (count()) so it costs one aggregation read regardless of how many posts
  /// the account has, instead of reading (and paying for) every document just to count them -
  /// unlike getPostsByUser's capped list, whose .length silently reports 100 for any account
  /// with 100+ posts (this is exactly why Arkib Pantun's profile showed "100" instead of its
  /// real ~5,642).
  Future<int> getPostCountByUser(String userId) async {
    try {
      final snapshot = await _posts.where('authorId', isEqualTo: userId).count().get();
      return snapshot.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<List<Post>> searchPosts(String query) async {
    try {
      final hashtagSnapshot =
          await _posts.where('hashtags', arrayContains: query).limit(20).get();
      final results = hashtagSnapshot.docs.map(Post.fromDoc).toList();

      if (results.length < 5) {
        final categorySnapshot =
            await _posts.where('category', isEqualTo: query).limit(20).get();
        final byId = {for (final p in results) p.id: p};
        for (final doc in categorySnapshot.docs) {
          final post = Post.fromDoc(doc);
          byId[post.id] = post;
        }
        return byId.values.toList();
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  /// Toggles the current user's like on a post and returns the resulting state (true = now
  /// liked). posts/{id}/likes/{userId} is the source of truth for "did this user already like
  /// this post" - the old likePost() wrote to that doc but never read it first, so every tap
  /// blindly did `likesCount + 1` with no ceiling and no way to undo a like. Doing the existence
  /// check and the counter update inside one transaction makes a like idempotent per user
  /// (rapid repeat taps just flip liked/unliked instead of stacking) and keeps likesCount
  /// consistent even under concurrent requests.
  Future<bool> toggleLike(String postId, String userId) async {
    final postRef = _posts.doc(postId);
    final likeRef = postRef.collection('likes').doc(userId);
    String? authorId;
    var nowLiked = false;
    await _firestore.runTransaction((transaction) async {
      // Both reads must happen before any write in a Firestore transaction.
      final likeSnapshot = await transaction.get(likeRef);
      final postSnapshot = await transaction.get(postRef);
      final currentLikes = (postSnapshot.data()?['likesCount'] as num?)?.toInt() ?? 0;
      authorId = postSnapshot.data()?['authorId'] as String?;
      nowLiked = !likeSnapshot.exists;
      if (nowLiked) {
        transaction.set(likeRef, {'timestamp': DateTime.now().millisecondsSinceEpoch});
        transaction.update(postRef, {'likesCount': currentLikes + 1});
      } else {
        transaction.delete(likeRef);
        transaction.update(postRef, {'likesCount': currentLikes > 0 ? currentLikes - 1 : 0});
      }
    });
    if (nowLiked) {
      await _notify(
        recipientId: authorId,
        senderId: userId,
        type: 'like',
        postId: postId,
        messageSuffix: 'liked your pantun',
      );
    }
    return nowLiked;
  }

  Future<bool> hasLiked(String postId, String userId) async {
    try {
      final doc = await _posts.doc(postId).collection('likes').doc(userId).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  /// Best-effort notification write to users/{recipient}/notifications. Never throws - a failed
  /// notification should not fail the action (like/comment) that triggered it. Writes both
  /// 'message' (Flutter AppNotification field) and 'text' (Kotlin NotificationItem field) so the
  /// same documents render in both apps.
  Future<void> _notify({
    required String? recipientId,
    required String senderId,
    required String type,
    String? postId,
    required String messageSuffix,
  }) async {
    if (recipientId == null || recipientId.isEmpty || recipientId == senderId) return;
    try {
      final senderDoc = await _firestore.collection('users').doc(senderId).get();
      final senderName = (senderDoc.data()?['username'] as String?) ?? 'Someone';
      final message = '$senderName $messageSuffix';
      await _firestore.collection('users').doc(recipientId).collection('notifications').add({
        'type': type,
        'fromUserId': senderId,
        'fromUsername': senderName,
        'postId': postId,
        'message': message,
        'text': message,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isRead': false,
      });
    } catch (_) {
      // best-effort only
    }
  }

  Future<void> savePost(String userId, Post post) async {
    await _firestore.collection('users').doc(userId).collection('saved_posts').doc(post.id).set(post.toMap());
  }

  Future<void> unsavePost(String userId, String postId) async {
    await _firestore.collection('users').doc(userId).collection('saved_posts').doc(postId).delete();
  }

  Future<List<Post>> getSavedPosts(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('saved_posts')
          .orderBy('timestamp', descending: true)
          .get();
      return snapshot.docs.map(Post.fromDoc).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addComment(String postId, Comment comment) async {
    final postRef = _posts.doc(postId);
    final commentRef = postRef.collection('comments').doc();
    final commentWithId = comment.copyWith(id: commentRef.id, postId: postId);

    String? authorId;
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(postRef);
      final currentComments = (snapshot.data()?['commentsCount'] as num?)?.toInt() ?? 0;
      authorId = snapshot.data()?['authorId'] as String?;
      transaction.set(commentRef, commentWithId.toMap());
      transaction.update(postRef, {'commentsCount': currentComments + 1});
    });
    await _notify(
      recipientId: authorId,
      senderId: comment.authorId,
      type: 'comment',
      postId: postId,
      messageSuffix: 'commented on your pantun',
    );
  }

  Future<List<Comment>> getComments(String postId) async {
    try {
      final snapshot =
          await _posts.doc(postId).collection('comments').orderBy('timestamp').get();
      return snapshot.docs.map(Comment.fromDoc).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> reportPost(String postId, String reporterId, String reason) async {
    await _firestore.collection('reports').add({
      'postId': postId,
      'reporterId': reporterId,
      'reason': reason,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
}
