import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/draft_model.dart';
import '../../models/pantun_theme.dart';
import '../../providers/create_pantun_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/desktop_page_shell.dart';
import '../../widgets/neomorphic_box.dart';
import '../../widgets/neomorphic_button.dart';

/// Mirrors ui/screens/create/CreatePantunScreen.kt, including the "Smart Post Creator" theme
/// picker (6 real themes + "Detect with AI" button) that replaced the old made-up categories.
class CreatePantunScreen extends StatefulWidget {
  const CreatePantunScreen({super.key, required this.onBack, required this.onSuccess});

  final VoidCallback onBack;
  final VoidCallback onSuccess;

  @override
  State<CreatePantunScreen> createState() => _CreatePantunScreenState();
}

class _CreatePantunScreenState extends State<CreatePantunScreen> {
  final _contentController = TextEditingController();
  String _category = PantunTheme.all.first;
  XFile? _selectedImage;
  int? _currentDraftId;
  final _picker = ImagePicker();

  void _loadDraft(Draft draft) {
    setState(() {
      _contentController.text = draft.content;
      _category = draft.category;
      _currentDraftId = draft.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CreatePantunProvider>(
      builder: (context, provider, _) {
        if (provider.suggestedTheme != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() => _category = provider.suggestedTheme!);
            provider.clearSuggestedTheme();
          });
        }
        if (provider.isSuccess) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            provider.resetSuccess();
            widget.onSuccess();
          });
        }

        return DesktopPageShell(
          // No sidebar item is "active" - Create is reached from every tab via the FAB/sidebar
          // button, not tied to one of them.
          rightPanel: provider.drafts.isEmpty
              ? null
              : _DraftsPanel(drafts: provider.drafts, onSelect: _loadDraft, onDelete: provider.deleteDraft),
          builder: (context, isDesktop) => _buildScaffold(context, provider, isDesktop),
        );
      },
    );
  }

  Widget _buildScaffold(BuildContext context, CreatePantunProvider provider, bool isDesktop) {
    return Scaffold(
          backgroundColor: AppColors.backgroundNeutral,
          appBar: AppBar(
            title: const Text('Create Pantun', style: TextStyle(fontWeight: FontWeight.bold)),
            leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack),
            actions: [
              IconButton(
                icon: const Icon(Icons.save_outlined, color: AppColors.textSecondary),
                onPressed: _contentController.text.isNotEmpty
                    ? () => provider.saveDraft(_contentController.text, _category, image: _selectedImage)
                    : null,
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // On desktop the drafts list lives in the right panel instead (more room to
                // actually read them) - showing this cramped horizontal strip too would just be
                // the same data twice.
                if (!isDesktop && provider.drafts.isNotEmpty) ...[
                  const Text('Your Drafts', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: provider.drafts.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final draft = provider.drafts[i];
                        return GestureDetector(
                          onTap: () => _loadDraft(draft),
                          child: SizedBox(
                            width: 140,
                            child: NeomorphicBox(
                              backgroundColor: Colors.white,
                              borderRadius: 16,
                              elevation: 2,
                              child: Stack(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(draft.content, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10)),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: IconButton(
                                      icon: const Icon(Icons.delete, size: 14, color: AppColors.textSecondary),
                                      onPressed: () => provider.deleteDraft(draft),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                const Text('Preview', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                NeomorphicBox(
                  backgroundColor: Colors.white,
                  borderRadius: 28,
                  elevation: 6,
                  child: SizedBox(
                    width: double.infinity,
                    height: 200,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _contentController.text.isEmpty ? 'Your pantun will appear here...' : _contentController.text,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, height: 1.4, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                NeomorphicBox(
                  backgroundColor: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Write your pantun', style: TextStyle(color: AppColors.textSecondary)),
                            Text('${_contentController.text.length}/200',
                                style: TextStyle(fontSize: 12, color: _contentController.text.length > 180 ? Colors.red : AppColors.textSecondary)),
                          ],
                        ),
                        TextField(
                          controller: _contentController,
                          maxLength: 200,
                          maxLines: 5,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: 'Pulau Pandan jauh ke tengah,\nGunung Daik bercabang tiga...',
                            border: InputBorder.none,
                            counterText: '',
                          ),
                        ),
                        const Divider(),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.primaryAccentStrong),
                              onPressed: () async {
                                final image = await _picker.pickImage(source: ImageSource.gallery);
                                if (image != null) setState(() => _selectedImage = image);
                              },
                            ),
                            const Text('Add background image', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Theme', style: TextStyle(fontWeight: FontWeight.bold)),
                    // Was a plain TextButton in AppColors.primaryAccent (softBlue) - easy to miss
                    // entirely for a headline AI feature. Now an outlined chip with an icon so it
                    // reads as a real action, in primaryAccentStrong for contrast.
                    OutlinedButton.icon(
                      onPressed: _contentController.text.isNotEmpty && !provider.isClassifying
                          ? () => provider.classifyTheme(_contentController.text)
                          : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryAccentStrong,
                        side: const BorderSide(color: AppColors.primaryAccentStrong),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: provider.isClassifying
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.auto_awesome, size: 16),
                      label: const Text('Detect with AI', style: TextStyle(fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: PantunTheme.all.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final theme = PantunTheme.all[i];
                      return ChoiceChip(
                        label: Text(theme),
                        selected: _category == theme,
                        selectedColor: AppColors.successGreen,
                        onSelected: (_) => setState(() => _category = theme),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),
                NeomorphicButton(
                  backgroundColor: AppColors.successGreen,
                  enabled: _contentController.text.isNotEmpty && !provider.isLoading,
                  onPressed: () => provider.createPost(
                    _contentController.text,
                    _category,
                    image: _selectedImage,
                    draftId: _currentDraftId,
                  ),
                  child: provider.isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Post Pantun', style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                if (provider.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(provider.error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
              ],
            ),
          ),
        );
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }
}

/// Desktop-only right panel: your saved drafts, given a proper vertical list instead of the
/// cramped horizontal scroller mobile uses - same data (CreatePantunProvider.drafts), same
/// tap-to-load and delete behavior.
class _DraftsPanel extends StatelessWidget {
  const _DraftsPanel({required this.drafts, required this.onSelect, required this.onDelete});

  final List<Draft> drafts;
  final void Function(Draft draft) onSelect;
  final void Function(Draft draft) onDelete;

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
        child: ListView(
        children: [
          const Text('Your drafts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 14),
          for (final draft in drafts)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => onSelect(draft),
                child: NeomorphicBox(
                  backgroundColor: Colors.white,
                  borderRadius: 14,
                  elevation: 3,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          draft.content,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.textPrimary),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 16, color: AppColors.textSecondary),
                        tooltip: 'Delete draft',
                        onPressed: () => onDelete(draft),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
        ),
      ),
    );
  }
}
