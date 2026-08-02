import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/user_profile_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neomorphic_box.dart';

/// Another user's profile - the entry point for following someone. Reached by tapping a post's
/// author (feed, explore, post detail) or a row in a followers/following list. Mirrors the
/// self-Profile screen's layout, with a Follow/Unfollow button and a Message shortcut where the
/// edit/settings actions would be.
class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({
    super.key,
    required this.onBack,
    required this.onNavigateToChat,
    required this.onNavigateToPostDetail,
    required this.onNavigateToFollowers,
    required this.onNavigateToFollowing,
  });

  final VoidCallback onBack;
  final void Function(String chatId) onNavigateToChat;
  final void Function(String postId) onNavigateToPostDetail;
  final void Function(String userId) onNavigateToFollowers;
  final void Function(String userId) onNavigateToFollowing;

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserProfileProvider>();
    final user = profile.user;

    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      appBar: AppBar(
        title: Text(user?.username ?? 'Profile'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
      ),
      body: profile.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.softBlue))
          : user == null
              ? const Center(child: Text('User not found.', style: TextStyle(color: AppColors.textSecondary)))
              : RefreshIndicator(
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
                                backgroundImage: user.profilePictureUrl.isNotEmpty
                                    ? CachedNetworkImageProvider(user.profilePictureUrl)
                                    : null,
                                child: user.profilePictureUrl.isEmpty
                                    ? Text(
                                        user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                                      )
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              Text(user.username, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  user.bio.isNotEmpty ? user.bio : 'Pencinta pantun.',
                                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 24),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _StatItem(
                                      count: user.followersCount,
                                      label: 'Followers',
                                      onTap: () => onNavigateToFollowers(user.id),
                                    ),
                                    _StatItem(
                                      count: user.followingCount,
                                      label: 'Following',
                                      onTap: () => onNavigateToFollowing(user.id),
                                    ),
                                    _StatItem(count: profile.postsCount, label: 'Pantun'),
                                  ],
                                ),
                              ),
                              if (!profile.isSelf)
                                Padding(
                                  padding: const EdgeInsets.only(top: 24),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: SizedBox(
                                          height: 46,
                                          child: ElevatedButton.icon(
                                            onPressed: profile.isFollowBusy ? null : profile.toggleFollow,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  profile.isFollowing ? Colors.white : AppColors.primaryAccentStrong,
                                              foregroundColor:
                                                  profile.isFollowing ? AppColors.primaryAccentStrong : Colors.white,
                                              side: profile.isFollowing
                                                  ? const BorderSide(color: AppColors.primaryAccentStrong)
                                                  : BorderSide.none,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(14)),
                                            ),
                                            icon: profile.isFollowBusy
                                                ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child: CircularProgressIndicator(strokeWidth: 2))
                                                : Icon(profile.isFollowing
                                                    ? Icons.check
                                                    : Icons.person_add_alt_1,
                                                    size: 18),
                                            label: Text(
                                              profile.isFollowing ? 'Following' : 'Follow',
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      SizedBox(
                                        height: 46,
                                        width: 46,
                                        child: OutlinedButton(
                                          onPressed: () => profile.startChat(onNavigateToChat),
                                          style: OutlinedButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            side: const BorderSide(color: AppColors.primaryAccentStrong),
                                            shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(14)),
                                          ),
                                          child: const Icon(Icons.chat_bubble_outline,
                                              size: 18, color: AppColors.primaryAccentStrong),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text('Pantun by ${user.username}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (profile.posts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                              child: Text('No pantun shared yet.', style: TextStyle(color: AppColors.textSecondary))),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.1,
                          ),
                          itemCount: profile.posts.length,
                          itemBuilder: (context, i) {
                            final post = profile.posts[i];
                            return GestureDetector(
                              onTap: () => onNavigateToPostDetail(post.id),
                              child: NeomorphicBox(
                                backgroundColor: const Color(0xFFF0F4F8),
                                borderRadius: 16,
                                elevation: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(post.content,
                                      maxLines: 5,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12)),
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
