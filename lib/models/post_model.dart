import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors domain/model/Post.kt
class Post {
  final String id;
  final String authorId;
  final String authorName;
  final String authorProfilePictureUrl;
  final String content;
  final String backgroundImageUrl;
  final String category;
  final List<String> hashtags;
  final int timestamp;
  final int likesCount;
  final int commentsCount;

  /// Whether the *current* user has liked this post. This is client-side-only state (never
  /// stored on the post document itself - it's derived from posts/{id}/likes/{userId}) so it's
  /// intentionally left out of toMap(). Defaults to false on a fresh fetch; providers update it
  /// locally via copyWith after a like/unlike round-trip.
  final bool isLiked;

  const Post({
    this.id = '',
    this.authorId = '',
    this.authorName = '',
    this.authorProfilePictureUrl = '',
    this.content = '',
    this.backgroundImageUrl = '',
    this.category = '',
    this.hashtags = const [],
    this.timestamp = 0,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLiked = false,
  });

  factory Post.fromMap(Map<String, dynamic> map, {String? overrideId}) {
    return Post(
      id: overrideId ?? map['id'] as String? ?? '',
      authorId: map['authorId'] as String? ?? '',
      authorName: map['authorName'] as String? ?? '',
      authorProfilePictureUrl: map['authorProfilePictureUrl'] as String? ?? '',
      content: map['content'] as String? ?? '',
      backgroundImageUrl: map['backgroundImageUrl'] as String? ?? '',
      category: map['category'] as String? ?? '',
      hashtags: (map['hashtags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
      likesCount: (map['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (map['commentsCount'] as num?)?.toInt() ?? 0,
    );
  }

  factory Post.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Post.fromMap(doc.data() ?? {}, overrideId: doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'authorId': authorId,
      'authorName': authorName,
      'authorProfilePictureUrl': authorProfilePictureUrl,
      'content': content,
      'backgroundImageUrl': backgroundImageUrl,
      'category': category,
      'hashtags': hashtags,
      'timestamp': timestamp,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
    };
  }

  Post copyWith({
    String? id,
    String? backgroundImageUrl,
    int? likesCount,
    int? commentsCount,
    bool? isLiked,
  }) {
    return Post(
      id: id ?? this.id,
      authorId: authorId,
      authorName: authorName,
      authorProfilePictureUrl: authorProfilePictureUrl,
      content: content,
      backgroundImageUrl: backgroundImageUrl ?? this.backgroundImageUrl,
      category: category,
      hashtags: hashtags,
      timestamp: timestamp,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}
