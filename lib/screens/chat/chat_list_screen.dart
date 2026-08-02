import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/chat_list_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neomorphic_box.dart';

/// Mirrors ui/screens/chat/ChatListScreen.kt, including the New Chat FAB and real-username
/// fixes made on the Kotlin side (it used to show a hardcoded "User Name" for every chat with no
/// way to start a new one).
class ChatListScreen extends StatelessWidget {
  const ChatListScreen({
    super.key,
    required this.onBack,
    required this.onNavigateToChat,
    required this.onNavigateToNewChat,
  });

  final VoidCallback onBack;
  final void Function(String chatId) onNavigateToChat;
  final void Function(String currentUserId) onNavigateToNewChat;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatListProvider>();

    return Scaffold(
      backgroundColor: AppColors.backgroundNeutral,
      appBar: AppBar(
        title: const Text('Messages'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryAccentStrong,
        tooltip: 'New chat',
        onPressed: () {
          final userId = provider.currentUserId;
          if (userId != null) onNavigateToNewChat(userId);
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryAccent))
          : provider.chats.isEmpty
              ? const Center(child: Text('No conversations yet. Tap + to message a friend.', style: TextStyle(color: AppColors.textSecondary)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.chats.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final chat = provider.chats[i];
                    final name = provider.displayNameFor(chat);
                    return GestureDetector(
                      onTap: () => onNavigateToChat(chat.id),
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
                                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        Text(
                                          DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(chat.lastMessageTimestamp)),
                                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                    Text(chat.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
