import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/ai_assistant_provider.dart';
import '../providers/home_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/search_provider.dart';
import '../repositories/auth_repository.dart';
import '../repositories/post_repository.dart';
import '../repositories/user_repository.dart';
import '../services/gemini_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/desktop_page_shell.dart';
import '../widgets/neomorphic_box.dart';
import 'ai/ai_assistant_screen.dart';
import 'home/home_screen.dart';
import 'profile/profile_screen.dart';
import 'search/search_screen.dart';

/// Persistent-tab shell for the four main destinations (Home / Search / AI / Profile).
///
/// Previously each bottom-nav icon pushed a whole new route with a back button, which made the
/// nav bar pointless. Now the pill nav lives here, above an IndexedStack that keeps all four
/// tabs (and their providers/scroll positions) alive while switching.
class MainShell extends StatefulWidget {
  // initialTab lets a sidebar tap from OUTSIDE MainShell (Post Detail, Settings, ...) land on a
  // specific tab: those screens can't switch MainShell's IndexedStack in place since they aren't
  // mounted inside it, so they instead navigate to `/home?tab=N`, which app_router.dart parses
  // and passes through here.
  const MainShell({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex = widget.initialTab.clamp(0, 3);

  void _setTab(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<HomeProvider>(
          create: (context) => HomeProvider(
            context.read<PostRepository>(),
            context.read<UserRepository>(),
            FirebaseAuth.instance,
          ),
        ),
        ChangeNotifierProvider<SearchProvider>(
          create: (context) => SearchProvider(context.read<PostRepository>(), context.read<UserRepository>()),
        ),
        ChangeNotifierProvider<AiAssistantProvider>(
          create: (context) => AiAssistantProvider(context.read<GeminiService>()),
        ),
        ChangeNotifierProvider<ProfileProvider>(
          create: (context) => ProfileProvider(
            context.read<UserRepository>(),
            context.read<PostRepository>(),
            context.read<AuthRepository>(),
            FirebaseAuth.instance,
          ),
        ),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= kDesktopBreakpoint;

          final tabs = IndexedStack(
            index: _currentIndex,
            children: [
              HomeScreen(
                onNavigateToAi: () => _setTab(2),
                onNavigateToCreate: () => context.push('/create-pantun'),
                onNavigateToProfile: () => _setTab(3),
                onNavigateToSearch: () => _setTab(1),
                onNavigateToChat: () => context.push('/chat-list'),
                onNavigateToNotifications: () => context.push('/notifications'),
                onNavigateToPostDetail: (postId) => context.push('/post/$postId'),
                onNavigateToUserProfile: (userId) => context.push('/user/$userId'),
                isDesktopLayout: isDesktop,
              ),
              SearchScreen(
                onBack: () => _setTab(0),
                onNavigateToPostDetail: (postId) => context.push('/post/$postId'),
                onNavigateToUserProfile: (userId) => context.push('/user/$userId'),
              ),
              AiAssistantScreen(onBack: () => _setTab(0)),
              ProfileScreen(
                onNavigateToSettings: () => context.push('/settings'),
                onNavigateToEditProfile: () => context.push('/edit-profile'),
                onNavigateToPostDetail: (postId) => context.push('/post/$postId'),
                onNavigateToFollowers: (userId) => context.push('/connections/$userId/followers'),
                onNavigateToFollowing: (userId) => context.push('/connections/$userId/following'),
              ),
            ],
          );

          return Scaffold(
            backgroundColor: AppColors.warmWhite,
            body: isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppSidebar(
                        active: const [SidebarItem.home, SidebarItem.search, SidebarItem.ai, SidebarItem.profile][_currentIndex],
                        onTapHome: () => _setTab(0),
                        onTapSearch: () => _setTab(1),
                        onTapAi: () => _setTab(2),
                        onTapProfile: () => _setTab(3),
                      ),
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 720),
                            child: tabs,
                          ),
                        ),
                      ),
                      if (_currentIndex == 0) const SizedBox(width: 280, child: _DesktopTrendingRail()),
                    ],
                  )
                : tabs,
            bottomNavigationBar: isDesktop ? null : _ShellBottomNav(currentIndex: _currentIndex, onTap: _setTab),
          );
        },
      ),
    );
  }
}

/// Desktop-only right rail showing the same "Trending Now" pantun that scroll horizontally on
/// mobile - moved here instead of duplicated inline above the feed, and only shown while the
/// Home tab is active (it reads live from HomeProvider, so it stays in sync with the feed).
class _DesktopTrendingRail extends StatelessWidget {
  const _DesktopTrendingRail();

  static const _colors = [
    AppColors.pastelPink,
    AppColors.softLavender,
    AppColors.mintGreen,
    AppColors.softBlue,
    AppColors.cream,
  ];

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeProvider>();
    if (home.trending.isEmpty) return const SizedBox.shrink();

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
          const Text('Trending Now 🔥', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 14),
          for (var i = 0; i < home.trending.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => context.push('/post/${home.trending[i].id}'),
                child: NeomorphicBox(
                  backgroundColor: _colors[i % _colors.length],
                  borderRadius: 16,
                  elevation: 3,
                  // NeomorphicBox defaults to padding: elevation/2 (here, 1.5px) when none is
                  // given - fine for tightly-wrapped controls like the sidebar's nav pill, but
                  // way too tight for a text card, which is why this looked cramped.
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        home.trending[i].category.isNotEmpty ? home.trending[i].category : 'Pantun',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        home.trending[i].content,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, height: 1.35, color: Colors.black87),
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

/// The floating neomorphic pill nav from HomeScreen.kt's `BottomNavigationBar` composable,
/// now shared by all four tabs with a live selected state.
class _ShellBottomNav extends StatelessWidget {
  const _ShellBottomNav({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final void Function(int index) onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          height: 70,
          child: NeomorphicBox(
            backgroundColor: Colors.white,
            borderRadius: 35,
            elevation: 8,
            padding: EdgeInsets.zero,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  icon: Icon(Icons.home, color: currentIndex == 0 ? AppColors.primaryAccentStrong : Colors.grey),
                  tooltip: 'Home',
                  onPressed: () => onTap(0),
                ),
                IconButton(
                  icon: Icon(Icons.search, color: currentIndex == 1 ? AppColors.primaryAccentStrong : Colors.grey),
                  tooltip: 'Search',
                  onPressed: () => onTap(1),
                ),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: currentIndex == 2 ? AppColors.softBlue.withOpacity(0.35) : AppColors.softBlue.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    // Previously always softBlue regardless of selection - the only one of the
                    // four tabs that didn't visibly change color when active. Now matches the
                    // same active/inactive swap as Home/Search/Profile, on top of the existing
                    // background-tint change.
                    icon: Icon(Icons.auto_awesome, color: currentIndex == 2 ? AppColors.primaryAccentStrong : Colors.grey),
                    tooltip: 'Pantun AI',
                    onPressed: () => onTap(2),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.person, color: currentIndex == 3 ? AppColors.primaryAccentStrong : Colors.grey),
                  tooltip: 'Profile',
                  onPressed: () => onTap(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
