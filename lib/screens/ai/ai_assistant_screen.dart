import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/ai_assistant_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/markdown_lite.dart';
import '../../widgets/neomorphic_box.dart';

/// Mirrors ui/screens/ai/AiAssistantScreen.kt (Exhibit 7, "Pantun AI Assistant").
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  static const _suggestions = ['Generate Romantic Pantun', 'Continue my Pantun...', 'Improve this Pantun', 'Explain this Pantun'];

  /// Strips markdown syntax so copied text is clean for sharing (no ** or > left behind).
  String _plainText(String markdown) {
    return markdown
        .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m.group(1)!)
        .replaceAllMapped(RegExp(r'\*(.+?)\*'), (m) => m.group(1)!)
        .replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^>\s?', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*(---|\*\*\*|___)\s*$', multiLine: true), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: _plainText(text)));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Copied', textAlign: TextAlign.center),
        duration: const Duration(milliseconds: 700),
        behavior: SnackBarBehavior.floating,
        width: 110,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ));
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    context.read<AiAssistantProvider>().sendMessage(text.trim());
    _inputController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiAssistantProvider>();

    return Scaffold(
      backgroundColor: AppColors.backgroundNeutral,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: AppColors.primaryAccentStrong, size: 20),
            SizedBox(width: 8),
            Text('Pantun AI'),
          ],
        ),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack),
      ),
      body: Column(
        children: [
          Expanded(
            // Flutter paints Text as pixels on a canvas rather than real browser text nodes, so
            // on web none of it is selectable by default - click-drag and Ctrl+C just don't do
            // anything, the same as it wouldn't on mobile. SelectionArea is Flutter's built-in
            // opt-in that turns every Text/Text.rich underneath it into real, click-and-drag
            // (or long-press-drag on touch) selectable text with a native copy menu - no extra
            // package needed. Wrapping it here also means selection can span across bubbles.
            child: SelectionArea(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                if (ai.messages.isEmpty)
                  const NeomorphicBox(
                    backgroundColor: Colors.white,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Apa khabar! I am your Pantun Assistant.', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('I can help you generate, complete, or improve Malay pantuns. Try one of the suggestions below!',
                              style: TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                for (final message in ai.messages)
                  Align(
                    alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        // Used to also have a long-press-anywhere-copies-the-whole-message
                        // GestureDetector here, but that competes with SelectionArea's own
                        // long-press-drag-to-select gesture on touch (and is redundant now that
                        // text can be selected and copied normally, partial selections included)
                        // - dropped in favor of just the explicit copy icon below.
                        child: NeomorphicBox(
                          backgroundColor: message.isUser
                              ? AppColors.primaryAccentStrong
                              : (message.isError ? Colors.red.shade50 : Colors.white),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // AI replies arrive as markdown - render them nicely; user
                                // messages stay plain text.
                                message.isUser
                                    ? Text(message.text, style: const TextStyle(color: Colors.white))
                                    : MarkdownLite(message.text),
                                InkWell(
                                  onTap: () => _copyToClipboard(message.text),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Icon(
                                      Icons.copy,
                                      size: 15,
                                      color: message.isUser ? Colors.white70 : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (ai.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => ActionChip(
                label: Text(_suggestions[i]),
                onPressed: () => _send(_suggestions[i]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    decoration: InputDecoration(
                      hintText: 'Ask Pantun AI...',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    ),
                    onSubmitted: _send,
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppColors.primaryAccentStrong,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: () => _send(_inputController.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
