import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/comment_model.dart';
import '../../models/post_model.dart';
import '../../providers/post_detail_provider.dart';
import '../../repositories/post_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/desktop_page_shell.dart';
import '../../widgets/neomorphic_box.dart';
import '../home/post_card.dart';

/// Mirrors ui/screens/post_detail/PostDetailScreen.kt exactly: reuses the same shared `PostCard`
/// composable as the Home feed (so the "..." Report/Block menu lives on the card itself, not a
/// separate app bar action), followed by a comment list and a dedicated comment input bar.
class PostDetailScreen extends StatelessWidget {
  const PostDetailScreen({
    super.key,
    required this.postId,
    required this.onBack,
    required this.onNavigateToUserProfile,
  });

  final String postId;
  final VoidCallback onBack;
  final void Function(String userId) onNavigateToUserProfile;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => PostDetailProvider(context.read<PostRepository>(), FirebaseAuth.instance, postId),
      child: _PostDetailView(onBack: onBack, onNavigateToUserProfile: onNavigateToUserProfile),
    );
  }
}

class _PostDetailView extends StatefulWidget {
  const _PostDetailView({required this.onBack, required this.onNavigateToUserProfile});

  final VoidCallback onBack;
  final void Function(String userId) onNavigateToUserProfile;

  @override
  State<_PostDetailView> createState() => _PostDetailViewState();
}

class _PostDetailViewState extends State<_PostDetailView> {
  final _commentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PostDetailProvider>();
    final post = provider.post;

    return DesktopPageShell(
      // No sidebar item is "active" for a post - it's reached from Home, Search, or a profile
      // grid, not any one fixed tab.
      rightPanel: post == null ? null : _MoreFromAuthorPanel(authorId: post.authorId, excludePostId: post.id),
      builder: (context, isDesktop) => _buildScaffold(context, provider, post),
    );
  }

  Widget _buildScaffold(BuildContext context, PostDetailProvider provider, Post? post) {
    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      appBar: AppBar(
        title: const Text('Pantun Details'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.softBlue))
          : Container(
              color: AppColors.warmWhite,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (post != null)
                    PostCard(
                      post: post,
                      onLike: provider.likePost,
                      onReport: () => provider.reportPost('Spam'),
                      onAuthorTap: () => widget.onNavigateToUserProfile(post.authorId),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('Comments (${provider.comments.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                  if (provider.comments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text('No comments yet. Be the first to reply!', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    )
                  else
                    for (final comment in provider.comments)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _CommentItem(
                          comment: comment,
                          onAuthorTap: comment.authorId.isEmpty ? null : () => widget.onNavigateToUserProfile(comment.authorId),
                        ),
                      ),
                ],
              ),
            ),
      bottomNavigationBar: _CommentInputBar(
        controller: _commentController,
        isSubmitting: provider.isSubmittingComment,
        onSend: () {
          if (_commentController.text.trim().isEmpty) return;
          provider.addComment(_commentController.text);
          _commentController.clear();
        },
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}

/// Mirrors PostDetailScreen.kt's `CommentItem` composable. Avatar + name now tap through to the
/// commenter's profile (previously dead-end text/graphics with no navigation at all).
class _CommentItem extends StatelessWidget {
  const _CommentItem({required this.comment, this.onAuthorTap});

  final Comment comment;
  final VoidCallback? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    return NeomorphicBox(
      backgroundColor: Colors.white,
      elevation: 2,
      borderRadius: 16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onAuthorTap,
            behavior: HitTestBehavior.opaque,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.mintGreenStrong,
              child: Text(
                comment.authorName.isNotEmpty ? comment.authorName[0].toUpperCase() : '?',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: onAuthorTap,
                      behavior: HitTestBehavior.opaque,
                      child: Text(comment.authorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMM dd, HH:mm').format(DateTime.fromMillisecondsSinceEpoch(comment.timestamp)),
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(comment.text, style: const TextStyle(fontSize: 14)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mirrors PostDetailScreen.kt's `CommentInputBar` composable.
class _CommentInputBar extends StatelessWidget {
  const _CommentInputBar({required this.controller, required this.isSubmitting, required this.onSend});

  final TextEditingController controller;
  final bool isSubmitting;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: NeomorphicBox(
                  backgroundColor: Colors.white,
                  elevation: 2,
                  borderRadius: 24,
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(hintText: 'Add a comment...', border: InputBorder.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              isSubmitting
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton(icon: const Icon(Icons.send_outlined, color: AppColors.primaryAccentStrong), tooltip: 'Send', onPressed: onSend),
            ],
          ),
        ),
      ),
    );
  }
}

/// Desktop-only right panel: a few more pantun by the same author, reusing the existing
/// `getPostsByUser` lookup (already used by the Profile screen's post grid) rather than
/// inventing a recommendation feature that doesn't exist. Not shown on mobile.
class _MoreFromAuthorPanel extends StatefulWidget {
  const _MoreFromAuthorPanel({required this.authorId, required this.excludePostId});

  final String authorId;
  final String excludePostId;

  @override
  State<_MoreFromAuthorPanel> createState() => _MoreFromAuthorPanelState();
}

class _MoreFromAuthorPanelState extends State<_MoreFromAuthorPanel> {
  late final Future<List<Post>> _future =
      context.read<PostRepository>().getPostsByUser(widget.authorId).then(
            (posts) => posts.where((p) => p.id != widget.excludePostId).take(3).toList(),
          );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(border: Border(left: BorderSide(color: Color(0x14000000)))),
      padding: const EdgeInsets.all(20),
      // decoration: none guards against Flutter's stray yellow-underline fallback when a Text
      // resolves without an explicit decoration override - see app_sidebar.dart for the full
      // explanation (same fix applied there for the nav pane labels).
      child: DefaultTextStyle.merge(
        style: const TextStyle(decoration: TextDecoration.none),
        child: FutureBuilder<List<Post>>(
        future: _future,
        builder: (context, snapshot) {
          final posts = snapshot.data ?? const [];
          if (snapshot.connectionState != ConnectionState.done || posts.isEmpty) {
            return const SizedBox.shrink();
          }
          return ListView(
            children: [
              const Text('More from this author', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 14),
              for (final post in posts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => context.push('/post/${post.id}'),
                    child: NeomorphicBox(
                      backgroundColor: Colors.white,
                      borderRadius: 14,
                      elevation: 3,
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        post.content,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.textPrimary),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        ),
      ),
    );
  }
}
