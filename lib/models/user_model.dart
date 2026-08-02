/// Mirrors domain/model/User.kt
class AppUser {
  final String id;
  final String username;
  final String email;
  final String profilePictureUrl;
  final String bio;
  final int followersCount;
  final int followingCount;
  final String favoriteCategory;

  const AppUser({
    this.id = '',
    this.username = '',
    this.email = '',
    this.profilePictureUrl = '',
    this.bio = '',
    this.followersCount = 0,
    this.followingCount = 0,
    this.favoriteCategory = '',
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String? ?? '',
      username: map['username'] as String? ?? '',
      email: map['email'] as String? ?? '',
      profilePictureUrl: map['profilePictureUrl'] as String? ?? '',
      bio: map['bio'] as String? ?? '',
      followersCount: (map['followersCount'] as num?)?.toInt() ?? 0,
      followingCount: (map['followingCount'] as num?)?.toInt() ?? 0,
      favoriteCategory: map['favoriteCategory'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'profilePictureUrl': profilePictureUrl,
      'bio': bio,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'favoriteCategory': favoriteCategory,
    };
  }

  AppUser copyWith({
    String? id,
    String? username,
    String? email,
    String? profilePictureUrl,
    String? bio,
    int? followersCount,
    int? followingCount,
    String? favoriteCategory,
  }) {
    return AppUser(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      bio: bio ?? this.bio,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      favoriteCategory: favoriteCategory ?? this.favoriteCategory,
    );
  }
}
