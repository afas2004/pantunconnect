import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';

/// Mirrors data/repository/UserRepository.kt, including the followers/following/getUsers
/// additions made on the Kotlin side (there was previously no way to list followers, or to
/// resolve a batch of user ids to profiles).
class UserRepository {
  UserRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users => _firestore.collection('users');
  CollectionReference<Map<String, dynamic>> get _follows => _firestore.collection('follows');

  Future<AppUser?> getUser(String userId) async {
    try {
      final doc = await _users.doc(userId).get();
      if (!doc.exists) return null;
      return AppUser.fromMap(doc.data()!);
    } catch (_) {
      return null;
    }
  }

  Future<void> updateUser(AppUser user) async {
    await _users.doc(user.id).set(user.toMap());
  }

  Future<bool> isFollowing(String currentUserId, String targetUserId) async {
    try {
      final query = await _follows
          .where('followerId', isEqualTo: currentUserId)
          .where('followingId', isEqualTo: targetUserId)
          .get();
      return query.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> followUser(String currentUserId, String targetUserId) async {
    final batch = _firestore.batch();

    final followRef = _follows.doc('${currentUserId}_$targetUserId');
    batch.set(followRef, {
      'followerId': currentUserId,
      'followingId': targetUserId,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });

    batch.update(_users.doc(currentUserId), {'followingCount': FieldValue.increment(1)});
    batch.update(_users.doc(targetUserId), {'followersCount': FieldValue.increment(1)});

    await batch.commit();

    // Best-effort follow notification (never throws; writes both 'message' and 'text' so it
    // renders in the Flutter and Kotlin notification screens alike).
    try {
      final senderDoc = await _users.doc(currentUserId).get();
      final senderName = (senderDoc.data()?['username'] as String?) ?? 'Someone';
      final message = '$senderName started following you';
      await _users.doc(targetUserId).collection('notifications').add({
        'type': 'follow',
        'fromUserId': currentUserId,
        'fromUsername': senderName,
        'postId': null,
        'message': message,
        'text': message,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isRead': false,
      });
    } catch (_) {}
  }

  Future<void> unfollowUser(String currentUserId, String targetUserId) async {
    final batch = _firestore.batch();

    final followRef = _follows.doc('${currentUserId}_$targetUserId');
    batch.delete(followRef);

    batch.update(_users.doc(currentUserId), {'followingCount': FieldValue.increment(-1)});
    batch.update(_users.doc(targetUserId), {'followersCount': FieldValue.increment(-1)});

    await batch.commit();
  }

  Future<List<String>> getFollowingIds(String userId) async {
    try {
      final snapshot = await _follows.where('followerId', isEqualTo: userId).get();
      return snapshot.docs.map((d) => d.data()['followingId'] as String).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> getFollowerIds(String userId) async {
    try {
      final snapshot = await _follows.where('followingId', isEqualTo: userId).get();
      return snapshot.docs.map((d) => d.data()['followerId'] as String).toList();
    } catch (_) {
      return [];
    }
  }

  /// Resolves a batch of user ids to full profiles. Firestore's whereIn supports at most 30
  /// values per query, chunked here defensively at 10.
  Future<List<AppUser>> getUsers(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    try {
      final distinct = userIds.toSet().toList();
      final results = <AppUser>[];
      for (var i = 0; i < distinct.length; i += 10) {
        final chunk = distinct.sublist(i, i + 10 > distinct.length ? distinct.length : i + 10);
        final snapshot =
            await _users.where(FieldPath.documentId, whereIn: chunk).get();
        results.addAll(snapshot.docs.map((d) => AppUser.fromMap(d.data())));
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  Future<List<AppUser>> getFollowers(String userId) async {
    return getUsers(await getFollowerIds(userId));
  }

  Future<List<AppUser>> getFollowing(String userId) async {
    return getUsers(await getFollowingIds(userId));
  }

  /// Prefix search on `username`. Firestore has no native "contains"/case-insensitive text
  /// search, so this uses the standard Firestore workaround: an orderBy + startAt/endAt range
  /// query, where the Unicode high code point '' sorts after virtually every real
  /// character, making the range match "starts with this prefix". It's a real Firestore query
  /// (not a client-side filter over the whole collection), so it stays cheap even with
  /// thousands of users.
  ///
  /// This is still case-sensitive (a Firestore limitation, not something fixable client-side
  /// without a duplicated lowercase field on every user doc), so it also tries a capitalized
  /// variant of the query since most seeded usernames start with a capital letter. It will still
  /// miss a search like "ahmad" matching "Ahmad Wari" if typed in a case the username doesn't
  /// start with - a proper fix would add a `usernameLower` field going forward.
  Future<List<AppUser>> searchUsers(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    try {
      final variants = {trimmed, _capitalize(trimmed)};
      final byId = <String, AppUser>{};
      for (final variant in variants) {
        final snapshot = await _users
            .orderBy('username')
            .startAt([variant])
            .endAt(['$variant'])
            .limit(20)
            .get();
        for (final doc in snapshot.docs) {
          final user = AppUser.fromMap(doc.data());
          byId[user.id.isNotEmpty ? user.id : doc.id] = user;
        }
      }
      return byId.values.toList();
    } catch (_) {
      return [];
    }
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Future<void> blockUser(String currentUserId, String targetUserId) async {
    await _users
        .doc(currentUserId)
        .collection('blocked_users')
        .doc(targetUserId)
        .set({'timestamp': DateTime.now().millisecondsSinceEpoch});
  }

  Future<Set<String>> getBlockedUserIds(String currentUserId) async {
    try {
      final snapshot = await _users.doc(currentUserId).collection('blocked_users').get();
      return snapshot.docs.map((d) => d.id).toSet();
    } catch (_) {
      return {};
    }
  }
}
