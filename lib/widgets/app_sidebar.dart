import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import 'neomorphic_box.dart';
import 'neomorphic_button.dart';

/// The six persistent desktop-sidebar destinations. `active` on [AppSidebar] highlights one of
/// these (or none, for a pushed screen that isn't really "any" tab - Post Detail, Create Pantun).
enum SidebarItem { home, search, ai, notifications, messages, profile }

/// Shared left nav used by every logged-in screen on wide layouts (see [DesktopPageShell]).
///
/// From inside MainShell, Home/Search/Pantun AI/Profile are overridden to switch tabs in place
/// (`onTapHome` etc.) so the IndexedStack's already-loaded state isn't thrown away. From any
/// other pushed screen (Post Detail, Create Pantun, Messaging, Settings, ...) those same four
/// items fall back to `context.go('/home?tab=N')`, which is the only way to reach a specific tab
/// from outside MainShell since tabs aren't separate routes. Notifications/Messages/Create always
/// push their real routes, everywhere.
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    this.active,
    this.onTapHome,
    this.onTapSearch,
    this.onTapAi,
    this.onTapProfile,
  });

  final SidebarItem? active;
  final VoidCallback? onTapHome;
  final VoidCallback? onTapSearch;
  final VoidCallback? onTapAi;
  final VoidCallback? onTapProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 232,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0x14000000))),
      ),
      // Explicit decoration: none guards against a Flutter fallback where a Text widget that
      // resolves without a decoration override renders with a stray yellow squiggly underline
      // (and red color, if color is also unset) - the mechanism behind the yellow lines reported
      // under the sidebar labels. Every Text below already sets its own color; this just pins
      // down decoration for the whole subtree in one place instead of on every TextStyle.
      child: DefaultTextStyle.merge(
        style: const TextStyle(decoration: TextDecoration.none),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('Pantun Connect',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primaryAccentStrong)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('Explore Malay Culture', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ),
          const SizedBox(height: 28),
          _SidebarItemTile(
            icon: Icons.home,
            label: 'Home',
            selected: active == SidebarItem.home,
            onTap: onTapHome ?? () => context.go('/home'),
          ),
          _SidebarItemTile(
            icon: Icons.search,
            label: 'Search',
            selected: active == SidebarItem.search,
            onTap: onTapSearch ?? () => context.go('/home?tab=1'),
          ),
          _SidebarItemTile(
            icon: Icons.auto_awesome,
            label: 'Pantun AI',
            selected: active == SidebarItem.ai,
            onTap: onTapAi ?? () => context.go('/home?tab=2'),
          ),
          _SidebarItemTile(
            icon: Icons.notifications_none,
            label: 'Notifications',
            selected: active == SidebarItem.notifications,
            onTap: () => context.push('/notifications'),
          ),
          _SidebarItemTile(
            icon: Icons.chat_bubble_outline,
            label: 'Messages',
            selected: active == SidebarItem.messages,
            // Goes straight into the shelled Messaging view (sidebar + conversations rail),
            // not `/chat-list` - that's a bare, un-shelled mobile screen with no sidebar of its
            // own, so tapping here used to mean landing on a page that looked broken and then
            // needing a second click just to get back the sidebar. `/chat-list` still exists and
            // is still correct for mobile, which has no sidebar to lose in the first place.
            onTap: () => context.go('/messaging'),
          ),
          _SidebarItemTile(
            icon: Icons.person_outline,
            label: 'Profile',
            selected: active == SidebarItem.profile,
            onTap: onTapProfile ?? () => context.go('/home?tab=3'),
          ),
          const SizedBox(height: 16),
          NeomorphicButton(
            onPressed: () => context.push('/create-pantun'),
            backgroundColor: AppColors.mintGreenStrong,
            borderRadius: 14,
            height: 46,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Create pantun', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _SidebarItemTile extends StatelessWidget {
  const _SidebarItemTile({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryAccentStrong : AppColors.textSecondary;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 14),
          Text(label, style: TextStyle(color: color, fontSize: 14, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GestureDetector(
        onTap: onTap,
        child: selected
            ? NeomorphicBox(
                backgroundColor: AppColors.softBlue.withOpacity(0.35),
                borderRadius: 12,
                elevation: 3,
                padding: EdgeInsets.zero,
                child: row,
              )
            : row,
      ),
    );
  }
}
