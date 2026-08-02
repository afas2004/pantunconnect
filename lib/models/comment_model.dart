import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors domain/model/Comment.kt
class Comment {
  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String text;
  final int timestamp;

  Comment({
    this.id = '',
    this.postId = '',
    this.authorId = '',
    this.authorName = '',
    this.text = '',
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  factory Comment.fromMap(Map<String, dynamic> map, {String? overrideId}) {
    return Comment(
      id: overrideId ?? map['id'] as String? ?? '',
      postId: map['postId'] as String? ?? '',
      authorId: map['authorId'] as String? ?? '',
      authorName: map['authorName'] as String? ?? '',
      text: map['text'] as String? ?? '',
      timestamp: (map['timestamp'] as num?)?.toInt(),
    );
  }

  factory Comment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Comment.fromMap(doc.data() ?? {}, overrideId: doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'postId': postId,
      'authorId': authorId,
      'authorName': authorName,
      'text': text,
      'timestamp': timestamp,
    };
  }

  Comment copyWith({String? id, String? postId}) => Comment(
        id: id ?? this.id,
        postId: postId ?? this.postId,
        authorId: authorId,
        authorName: authorName,
        text: text,
        timestamp: timestamp,
      );
}
