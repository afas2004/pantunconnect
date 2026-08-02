import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/post_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neomorphic_box.dart';

/// Relative "time ago" label (the Kotlin PostCard hardcodes "Just now" for every post - this
/// replaces that placeholder with the real post age).
String _timeAgo(int timestampMs) {
  if (timestampMs <= 0) return '';
  final time = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('d MMM yyyy').format(time);
}

/// Mirrors ui/screens/home/HomeScreen.kt's `PostCard` composable exactly (reused by Home,
/// PostDetail, and Search screens - same as in the Kotlin app): a square tinted-pink avatar
/// surface with the author's first initial, a "..." menu with Report Post / Block User, the
/// pantun text at 18sp/28sp line-height, and a like/comment/share icon row.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onLike,
    this.onClick,
    this.onReport,
    this.onBlock,
    this.onAuthorTap,
  });

  final Post post;
  final VoidCallback onLike;
  final VoidCallback? onClick;

  /// Mirrors the Kotlin dropdown's "Report Post" item, which always reports with the default
  /// reason "Spam" (`onReport = { viewModel.reportPost(post.id) }`).
  final VoidCallback? onReport;

  /// "Block User" - a no-op in the Kotlin dropdown; wired for real here (records the block and
  /// hides the author's posts from the feed).
  final VoidCallback? onBlock;

  /// Tapping the author's avatar/name opens their profile (where the Follow button lives).
  final VoidCallback? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClick,
      child: NeomorphicBox(
        backgroundColor: Colors.white,
        borderRadius: 28,
        elevation: 6,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: onAuthorTap,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.pastelPink.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            post.authorName.isNotEmpty ? post.authorName[0].toUpperCase() : '?',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.pastelPinkStrong),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(post.authorName.isEmpty ? 'User' : post.authorName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(_timeAgo(post.timestamp), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                    onSelected: (value) {
                      if (value == 'report') onReport?.call();
                      if (value == 'block') onBlock?.call();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'report',
                        child: Row(children: [Icon(Icons.flag_outlined, size: 18), SizedBox(width: 8), Text('Report Post')]),
                      ),
                      PopupMenuItem(
                        value: 'block',
                        child: Row(children: [Icon(Icons.block, size: 18), SizedBox(width: 8), Text('Block User')]),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                post.content,
                style: const TextStyle(fontSize: 18, height: 28 / 18, fontWeight: FontWeight.w500, color: Colors.black87),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      post.isLiked ? Icons.favorite : Icons.favorite_border,
                      color: AppColors.pastelPinkStrong,
                    ),
                    tooltip: post.isLiked ? 'Unlike' : 'Like',
                    onPressed: onLike,
                  ),
                  Text('${post.likesCount}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 20),
                  const Icon(Icons.comment, size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text('${post.commentsCount}', style: const TextStyle(color: AppColors.textSecondary)),
                  const Spacer(),
                  const Icon(Icons.share, size: 20, color: AppColors.textSecondary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
