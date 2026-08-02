import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/profile_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neomorphic_box.dart';

/// Mirrors ui/screens/profile/ProfileScreen.kt, including the clickable followers/following
/// stats and real avatar rendering added on the Kotlin side (previously static text + initials
/// only, with the "Followers"/"Following" numbers not going anywhere).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.onNavigateToSettings,
    required this.onNavigateToEditProfile,
    required this.onNavigateToPostDetail,
    required this.onNavigateToFollowers,
    required this.onNavigateToFollowing,
  });

  final VoidCallback onNavigateToSettings;
  final VoidCallback onNavigateToEditProfile;
  final void Function(String postId) onNavigateToPostDetail;
  final void Function(String userId) onNavigateToFollowers;
  final void Function(String userId) onNavigateToFollowing;

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final user = profile.user;

    return Scaffold(
      backgroundColor: AppColors.backgroundNeutral,
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: onNavigateToEditProfile),
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: onNavigateToSettings),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: profile.refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            NeomorphicBox(
              backgroundColor: Colors.white,
              borderRadius: 30,
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppColors.primaryAccentStrong,
                      backgroundImage: (user?.profilePictureUrl.isNotEmpty ?? false)
                          ? CachedNetworkImageProvider(user!.profilePictureUrl)
                          : null,
                      child: (user?.profilePictureUrl.isEmpty ?? true)
                          ? Text(
                              user != null && user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(user?.username ?? 'User Name', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        (user?.bio.isNotEmpty ?? false) ? user!.bio : 'No bio yet. Start sharing pantun!',
                        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatItem(
                            count: user?.followersCount ?? 0,
                            label: 'Followers',
                            onTap: user != null ? () => onNavigateToFollowers(user.id) : null,
                          ),
                          _StatItem(
                            count: user?.followingCount ?? 0,
                            label: 'Following',
                            onTap: user != null ? () => onNavigateToFollowing(user.id) : null,
                          ),
                          _StatItem(count: profile.userPostsCount, label: 'Pantun'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('My Pantun Collections', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1,
              ),
              itemCount: profile.userPosts.length,
              itemBuilder: (context, i) {
                final post = profile.userPosts[i];
                return GestureDetector(
                  onTap: () => onNavigateToPostDetail(post.id),
                  child: NeomorphicBox(
                    backgroundColor: const Color(0xFFF0F4F8),
                    borderRadius: 16,
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(post.content, maxLines: 5, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.count, required this.label, this.onTap});

  final int count;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text('$count', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
