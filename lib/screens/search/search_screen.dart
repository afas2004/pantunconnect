import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/pantun_theme.dart';
import '../../models/user_model.dart';
import '../../providers/search_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neomorphic_box.dart';
import '../home/post_card.dart';

/// Mirrors ui/screens/search/SearchScreen.kt (Exhibit 6, "Explore / Search Screen"), with the
/// browse chips upgraded from placeholder hashtags to the real 6-theme taxonomy from the
/// "Klasifikasi Pantun 6 Tema Baharu" dataset - tapping a theme filters the feed by that
/// category (posts are tagged with these exact theme names by the Smart Post Creator).
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.onBack,
    required this.onNavigateToPostDetail,
    required this.onNavigateToUserProfile,
  });

  final VoidCallback onBack;
  final void Function(String postId) onNavigateToPostDetail;
  final void Function(String userId) onNavigateToUserProfile;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();

  void _search(String query) {
    // Keep the text field and provider in sync whether the query came from typing or a chip tap.
    if (_searchController.text != query) {
      _searchController.text = query;
      _searchController.selection = TextSelection.collapsed(offset: query.length);
    }
    context.read<SearchProvider>().onQueryChange(query);
  }

  @override
  Widget build(BuildContext context) {
    final search = context.watch<SearchProvider>();

    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      appBar: AppBar(
        title: const Text('Explore Pantun', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            NeomorphicBox(
              backgroundColor: Colors.white,
              borderRadius: 24,
              child: TextField(
                controller: _searchController,
                onChanged: _search,
                decoration: const InputDecoration(
                  hintText: 'Search hashtags, users, or keywords...',
                  prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              search.query.isEmpty ? 'Browse by Theme' : 'Search Results',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            if (search.query.isEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final theme in PantunTheme.all)
                    ActionChip(
                      label: Text(theme, style: const TextStyle(fontSize: 13)),
                      backgroundColor: Colors.white,
                      onPressed: () => _search(theme),
                    ),
                ],
              ),
            Expanded(
              child: search.isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.softBlue))
                  : (search.results.isEmpty && search.userResults.isEmpty && search.query.isNotEmpty)
                      ? Center(child: Text('No results found for "${search.query}"', style: const TextStyle(color: AppColors.textSecondary)))
                      : ListView(
                          padding: const EdgeInsets.only(top: 12, bottom: 24),
                          children: [
                            if (search.userResults.isNotEmpty) ...[
                              const Text('People', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                              const SizedBox(height: 8),
                              for (final user in search.userResults)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _UserResultTile(
                                    user: user,
                                    onTap: () => widget.onNavigateToUserProfile(user.id),
                                  ),
                                ),
                              const SizedBox(height: 12),
                            ],
                            if (search.results.isNotEmpty) ...[
                              const Text('Pantun', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                              const SizedBox(height: 8),
                            ],
                            for (final post in search.results)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: PostCard(
                                  post: post,
                                  onLike: () {},
                                  onClick: () => widget.onNavigateToPostDetail(post.id),
                                  onAuthorTap: () => widget.onNavigateToUserProfile(post.authorId),
                                ),
                              ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

/// A matched user in search results - the search bar's hint text has always promised "hashtags,
/// users, or keywords" but user search was never actually wired up before now.
class _UserResultTile extends StatelessWidget {
  const _UserResultTile({required this.user, required this.onTap});

  final AppUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: NeomorphicBox(
        backgroundColor: Colors.white,
        borderRadius: 16,
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primaryAccentStrong,
                child: Text(user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
