/// Mirrors data/local/entity/DraftEntity.kt. Stored locally (Hive) instead of Room, so it also
/// works on Flutter Web (IndexedDB-backed).
class Draft {
  final int? id;
  final String content;
  final String category;
  final String? imageUrl;

  const Draft({
    this.id,
    required this.content,
    required this.category,
    this.imageUrl,
  });

  factory Draft.fromMap(int id, Map<dynamic, dynamic> map) {
    return Draft(
      id: id,
      content: map['content'] as String? ?? '',
      category: map['category'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'content': content,
      'category': category,
      'imageUrl': imageUrl,
    };
  }

  Draft copyWith({int? id}) => Draft(
        id: id ?? this.id,
        content: content,
        category: category,
        imageUrl: imageUrl,
      );
}
