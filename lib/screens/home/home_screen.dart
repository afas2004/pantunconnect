import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/post_model.dart';
import '../../providers/home_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neomorphic_box.dart';
import 'post_card.dart';

/// Mirrors ui/screens/home/HomeScreen.kt (Exhibit 4, "Home Feed Dashboard").
///
/// Two deliberate departures from the Kotlin composable:
/// - The bottom nav pill moved up into MainShell (persistent tabs instead of pushed routes).
/// - "Trending Now" shows a random sample of REAL pantun (tappable, fire-emoji flair) instead of
///   the Kotlin version's five hardcoded, non-tappable hashtag cards.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onNavigateToAi,
    required this.onNavigateToCreate,
    required this.onNavigateToProfile,
    required this.onNavigateToSearch,
    required this.onNavigateToChat,
    required this.onNavigateToNotifications,
    required this.onNavigateToPostDetail,
    required this.onNavigateToUserProfile,
    this.isDesktopLayout = false,
  });

  final VoidCallback onNavigateToAi;
  final VoidCallback onNavigateToCreate;
  final VoidCallback onNavigateToProfile;
  final VoidCallback onNavigateToSearch;
  final VoidCallback onNavigateToChat;
  final VoidCallback onNavigateToNotifications;
  final void Function(String postId) onNavigateToPostDetail;
  final void Function(String userId) onNavigateToUserProfile;
  // Set by MainShell on wide (desktop) layouts, where the sidebar already covers branding,
  // notifications, messages, and "create" - showing them again here would just duplicate the
  // sidebar. On narrow/mobile layouts this stays false and the screen looks exactly as before.
  final bool isDesktopLayout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scrollController = ScrollController();

  // Mirrors TrendingCard's fixed pastel color rotation.
  static const _trendingColors = [
    AppColors.pastelPink,
    AppColors.softLavender,
    AppColors.mintGreen,
    AppColors.softBlue,
    AppColors.cream,
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 300) {
        context.read<HomeProvider>().loadMore();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeProvider>();

    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      // On desktop the sidebar's "Create pantun" button already covers this - showing the FAB
      // too would just be a second identical affordance competing for attention.
      floatingActionButton: widget.isDesktopLayout
          ? null
          : FloatingActionButton(
              onPressed: widget.onNavigateToCreate,
              backgroundColor: AppColors.mintGreen,
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.add),
            ),
      body: RefreshIndicator(
        onRefresh: home.refresh,
        child: Container(
          color: AppColors.warmWhite,
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              // Wordmark + notification/chat icons and the trending carousel move into the
              // sidebar and right rail on desktop (see MainShell) - repeating them here would
              // just be visual clutter on top of what's already in the sidebar.
              if (!widget.isDesktopLayout)
                _HomeTopBar(onChatClick: widget.onNavigateToChat, onNotificationClick: widget.onNavigateToNotifications),
              if (!widget.isDesktopLayout && home.trending.isNotEmpty)
                _TrendingSection(
                  posts: home.trending,
                  colors: _trendingColors,
                  onTapPost: widget.onNavigateToPostDetail,
                ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Recent Pantun', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
              if (home.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator(color: AppColors.softBlue)),
                )
              else if (home.posts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: Text('No pantun yet. Be the first to share one!', style: TextStyle(color: AppColors.textSecondary))),
                )
              else
                for (final post in home.posts)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: PostCard(
                      post: post,
                      onLike: () => home.toggleLike(post.id),
                      onClick: () => widget.onNavigateToPostDetail(post.id),
                      onReport: () => home.reportPost(post.id),
                      onBlock: () => home.blockUser(post.authorId),
                      onAuthorTap: () => widget.onNavigateToUserProfile(post.authorId),
                    ),
                  ),
              if (home.isLoadingMore)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator(color: AppColors.softBlue)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

/// Mirrors HomeScreen.kt's `HomeTopBar` composable.
class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({required this.onChatClick, required this.onNotificationClick});

  final VoidCallback onChatClick;
  final VoidCallback onNotificationClick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Pantun Connect', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primaryAccentStrong)),
              Text('Explore Malay Culture', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          Row(
            children: [
              _NotificationBell(onPressed: onNotificationClick),
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline, color: AppColors.textSecondary),
                tooltip: 'Messages',
                onPressed: onChatClick,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Notification bell with a small red dot when there's at least one unread notification.
/// Uses a `limit(1)` real-time listener - we only need to know whether any unread doc exists,
/// not how many, so this stays a single cheap live document read regardless of how many
/// notifications the user has.
class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_none, color: AppColors.textSecondary),
          tooltip: 'Notifications',
          onPressed: onPressed,
        ),
        if (userId != null)
          Positioned(
            right: 6,
            top: 6,
            child: IgnorePointer(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('notifications')
                    .where('isRead', isEqualTo: false)
                    .limit(1)
                    .snapshots(),
                builder: (context, snapshot) {
                  final hasUnread = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
                  if (!hasUnread) return const SizedBox.shrink();
                  return Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.pastelPinkStrong,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.warmWhite, width: 1.5),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// "Trending Now" with real, randomly-sampled pantun on the pastel cards.
class _TrendingSection extends StatelessWidget {
  const _TrendingSection({required this.posts, required this.colors, required this.onTapPost});

  final List<Post> posts;
  final List<Color> colors;
  final void Function(String postId) onTapPost;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Trending Now 🔥', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
        ),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: posts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, i) {
              final post = posts[i];
              return GestureDetector(
                onTap: () => onTapPost(post.id),
                child: NeomorphicBox(
                  backgroundColor: colors[i % colors.length],
                  borderRadius: 24,
                  elevation: 4,
                  padding: EdgeInsets.zero,
                  child: SizedBox(
                    width: 190,
                    height: 110,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('🔥', style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  post.category.isNotEmpty ? post.category : 'Pantun',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: Text(
                              post.content,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, height: 1.35, fontWeight: FontWeight.w500, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
