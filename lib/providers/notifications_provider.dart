import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Mirrors ui/screens/notifications/NotificationsViewModel.kt.
///
/// NOTE: the original Kotlin app has no dedicated NotificationRepository/backend for this
/// screen (there's no notification-writing code anywhere in the app - follows, likes, and
/// comments don't create notification documents), so NotificationsScreen there is effectively
/// UI-only (a loading spinner with nothing to load). This port reads from a real
/// `users/{uid}/notifications` subcollection, following the same per-user subcollection pattern
/// already used for saved_posts/blocked_users - so notifications will show up once something
/// (e.g. a Cloud Function, or a future feature) actually writes to that subcollection.
class AppNotification {
  final String id;
  final String type;
  final String message;
  final int timestamp;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.type,
    required this.message,
    required this.timestamp,
    required this.isRead,
  });

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppNotification(
      id: doc.id,
      type: data['type'] as String? ?? 'general',
      message: data['message'] as String? ?? '',
      timestamp: (data['timestamp'] as num?)?.toInt() ?? 0,
      isRead: data['isRead'] as bool? ?? false,
    );
  }
}

class NotificationsProvider extends ChangeNotifier {
  NotificationsProvider(this._firestore, this._auth) {
    _load();
  }

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  List<AppNotification> notifications = [];
  bool isLoading = false;
  String? error;

  Future<void> _load() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    isLoading = true;
    notifyListeners();
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .get();
      notifications = snapshot.docs.map(AppNotification.fromDoc).toList();
    } catch (e) {
      error = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() => _load();

  Future<void> markAsRead(String notificationId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
    notifications = notifications
        .map((n) => n.id == notificationId
            ? AppNotification(id: n.id, type: n.type, message: n.message, timestamp: n.timestamp, isRead: true)
            : n)
        .toList();
    notifyListeners();
  }
}
