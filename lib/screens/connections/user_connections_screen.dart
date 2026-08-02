import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/user_connections_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neomorphic_box.dart';

/// Mirrors ui/screens/connections/UserConnectionsScreen.kt: shows a user's followers/following,
/// and lets you start a chat with any of them. This screen didn't exist at all before - profile
/// stats were just numbers with nowhere to tap through to.
class UserConnectionsScreen extends StatefulWidget {
  const UserConnectionsScreen({
    super.key,
    required this.userId,
    required this.onBack,
    required this.onNavigateToChat,
    required this.onNavigateToProfile,
    this.initialTab = 'following',
  });

  final String userId;
  final String initialTab;
  final VoidCallback onBack;
  final void Function(String chatId) onNavigateToChat;
  final void Function(String userId) onNavigateToProfile;

  @override
  State<UserConnectionsScreen> createState() => _UserConnectionsScreenState();
}

class _UserConnectionsScreenState extends State<UserConnectionsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab == 'followers' ? 0 : 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserConnectionsProvider>().load(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserConnectionsProvider>();

    return Scaffold(
      backgroundColor: AppColors.backgroundNeutral,
      appBar: AppBar(
        title: const Text('Connections'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Followers (${provider.followers.length})'),
            Tab(text: 'Following (${provider.following.length})'),
          ],
        ),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryAccent))
          : TabBarView(
              controller: _tabController,
              children: [
                _ConnectionsList(
                    users: provider.followers,
                    emptyText: 'No followers yet.',
                    provider: provider,
                    onNavigateToChat: widget.onNavigateToChat,
                    onNavigateToProfile: widget.onNavigateToProfile),
                _ConnectionsList(
                    users: provider.following,
                    emptyText: 'Not following anyone yet.',
                    provider: provider,
                    onNavigateToChat: widget.onNavigateToChat,
                    onNavigateToProfile: widget.onNavigateToProfile),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

class _ConnectionsList extends StatelessWidget {
  const _ConnectionsList({
    required this.users,
    required this.emptyText,
    required this.provider,
    required this.onNavigateToChat,
    required this.onNavigateToProfile,
  });

  final List<AppUser> users;
  final String emptyText;
  final UserConnectionsProvider provider;
  final void Function(String chatId) onNavigateToChat;
  final void Function(String userId) onNavigateToProfile;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Center(child: Text(emptyText, style: const TextStyle(color: AppColors.textSecondary)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final user = users[i];
        void startChat() => provider.startChat(user.id, onNavigateToChat);
        // Row tap opens the user's profile (where Follow lives); the chat icon starts a DM.
        return GestureDetector(
          onTap: () => onNavigateToProfile(user.id),
          child: NeomorphicBox(
            backgroundColor: Colors.white,
            borderRadius: 16,
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.avatarLavender,
                    child: Text(user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.username.isEmpty ? 'User' : user.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        if (user.bio.isNotEmpty)
                          Text(user.bio, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.chat_bubble_outline, color: AppColors.primaryAccentStrong), tooltip: 'Message', onPressed: startChat),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
