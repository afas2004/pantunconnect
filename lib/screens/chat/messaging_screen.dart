import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../providers/chat_list_provider.dart';
import '../../providers/messaging_provider.dart';
import '../../repositories/chat_repository.dart';
import '../../repositories/user_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/desktop_page_shell.dart';
import '../../widgets/neomorphic_box.dart';

/// Mirrors ui/screens/chat/MessagingScreen.kt. The app bar shows the real other-participant's
/// name/avatar (a deliberate bug fix - the Kotlin screen never resolves who it's chatting with,
/// so its title is always the static "Chat"); bubble color/shape and the input field match the
/// Kotlin composable exactly (SoftLavender "me" bubble with an asymmetric tail corner, no
/// per-message timestamp).
class MessagingScreen extends StatelessWidget {
  // chatId is '' when reached via the sidebar's "Messages" item with nothing selected yet (see
  // the no-param `/messaging` route in app_router.dart) - onBack is nullable to match, since
  // that entry point is reached via `context.go`, which has nothing to pop back to.
  const MessagingScreen({super.key, required this.chatId, required this.onBack});

  final String chatId;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final hasChatSelected = chatId.isNotEmpty;
    return MultiProvider(
      providers: [
        if (hasChatSelected)
          ChangeNotifierProvider<MessagingProvider>(
            create: (context) => MessagingProvider(
              context.read<ChatRepository>(),
              context.read<UserRepository>(),
              FirebaseAuth.instance,
              chatId,
            ),
          ),
        // Feeds the desktop conversations rail (_ConversationsRail below) - a second, fresh
        // ChatListProvider instance, same pattern as every other per-route provider in this app,
        // independent from the one ChatListScreen's own route creates.
        ChangeNotifierProvider<ChatListProvider>(
          create: (context) => ChatListProvider(
            context.read<ChatRepository>(),
            context.read<UserRepository>(),
            FirebaseAuth.instance,
          ),
        ),
      ],
      child: DesktopPageShell(
        active: SidebarItem.messages,
        leftPanel: _ConversationsRail(currentChatId: chatId),
        leftPanelWidth: 240,
        builder: (context, isDesktop) =>
            hasChatSelected ? _MessagingView(onBack: onBack) : _NoChatSelectedView(onBack: onBack),
      ),
    );
  }
}

/// Shown when Messages is opened from the sidebar with nothing selected yet - the rail is
/// visible (same as always) but the thread pane just invites picking a conversation, rather than
/// showing a blank Scaffold or forcing a redirect through the separate mobile chat-list screen.
class _NoChatSelectedView extends StatelessWidget {
  const _NoChatSelectedView({required this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      appBar: AppBar(
        title: const Text('Messages'),
        leading: onBack == null ? null : IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
        automaticallyImplyLeading: onBack != null,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Select a conversation to start chatting', style: TextStyle(color: AppColors.textSecondary)),
        ),
      ),
    );
  }
}

/// Desktop-only panel between the sidebar and the open thread, listing every conversation
/// (reusing ChatListProvider - the same data ChatListScreen shows) so switching chats doesn't
/// mean leaving the one you're reading, the way WhatsApp Web/Messenger work. Not shown on mobile.
class _ConversationsRail extends StatelessWidget {
  const _ConversationsRail({required this.currentChatId});

  final String currentChatId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatListProvider>();
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0x14000000))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      // decoration: none guards against Flutter's stray yellow-underline fallback when a Text
      // resolves without an explicit decoration override - see app_sidebar.dart for the full
      // explanation (same fix applied there for the nav pane labels; this rail's tiles were
      // showing the same artifact on names/previews).
      child: DefaultTextStyle.merge(
        style: const TextStyle(decoration: TextDecoration.none),
        child: provider.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.softBlue))
          : ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: Text('Messages', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
                for (final chat in provider.chats)
                  _ConversationTile(
                    name: provider.displayNameFor(chat),
                    preview: chat.lastMessage,
                    active: chat.id == currentChatId,
                    onTap: () => context.go('/messaging/${chat.id}'),
                  ),
              ],
            ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.name, required this.preview, required this.active, required this.onTap});

  final String name;
  final String preview;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.softBlue.withOpacity(0.3) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.avatarLavender,
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(preview, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessagingView extends StatefulWidget {
  const _MessagingView({required this.onBack});

  final VoidCallback? onBack;

  @override
  State<_MessagingView> createState() => _MessagingViewState();
}

class _MessagingViewState extends State<_MessagingView> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  Future<void> _send() async {
    final provider = context.read<MessagingProvider>();
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    // Previously this fired sendMessage without awaiting it and cleared the input
    // unconditionally right after - so if the Firestore write failed (e.g. a permission-denied
    // from security rules), the input still emptied as if it had sent, the message never
    // appeared, and nothing told the user anything had gone wrong. Now we await the result and
    // only clear on success, surfacing failures with a SnackBar instead of hiding them.
    await provider.sendMessage(text);
    if (!mounted) return;
    if (provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message failed to send: ${provider.error}')),
      );
      return;
    }
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MessagingProvider>();
    final currentUserId = provider.currentUserId;
    final otherUser = provider.otherUser;

    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack),
        title: otherUser == null
            ? const Text('Chat')
            : Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.softLavender,
                    child: Text(
                      otherUser.username.isNotEmpty ? otherUser.username[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(otherUser.username),
                ],
              ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                controller: _scrollController,
                itemCount: provider.messages.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final message = provider.messages[i];
                  final isMe = message.senderId == currentUserId;
                  return _MessageBubble(text: message.text, isCurrentUser: isMe);
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppColors.softBlue),
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: IconButton(icon: const Icon(Icons.send, color: AppColors.primaryAccentStrong), tooltip: 'Send', onPressed: _send),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

/// Mirrors MessagingScreen.kt's `MessageBubble` composable exactly.
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.text, required this.isCurrentUser});

  final String text;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final bgColor = isCurrentUser ? AppColors.softLavender : AppColors.warmWhite;
    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: NeomorphicBox(
        backgroundColor: bgColor,
        elevation: 4,
        borderRadius: 20,
        padding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          child: Text(text, style: const TextStyle(fontSize: 15)),
        ),
      ),
    );
  }
}
