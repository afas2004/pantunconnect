import 'package:flutter/material.dart';

import 'app_sidebar.dart';

/// The single width threshold that decides mobile vs. desktop layout everywhere in the app -
/// MainShell and every [DesktopPageShell] use this same constant so the switch happens at the
/// same point for every screen.
const double kDesktopBreakpoint = 900;

/// Wraps a pushed-route screen (Post Detail, Create Pantun, Messaging, Settings, ...) with the
/// same persistent sidebar the four main tabs already get inside MainShell, so navigating deeper
/// into the app doesn't mean losing it and going back to a bare full-bleed page.
///
/// Below [kDesktopBreakpoint] this renders exactly what [builder] returns, unchanged - mobile
/// behavior is untouched. At or above it, [builder]'s result is centered and capped at
/// [contentMaxWidth], with [AppSidebar] on the left and, if given, [leftPanel] (a secondary panel
/// between the sidebar and the content - used by Messaging for its conversation list) and/or
/// [rightPanel] (used by Post Detail and Create Pantun for page-specific real data).
///
/// [builder] receives `isDesktop` so a screen can skip rendering something that would otherwise
/// be duplicated by [leftPanel]/[rightPanel] (e.g. Create Pantun's drafts strip moves into
/// [rightPanel] on desktop, so the mobile-only horizontal scroller is hidden there).
class DesktopPageShell extends StatelessWidget {
  const DesktopPageShell({
    super.key,
    required this.builder,
    this.active,
    this.leftPanel,
    this.leftPanelWidth = 240,
    this.rightPanel,
    this.rightPanelWidth = 270,
    this.contentMaxWidth = 720,
  });

  final Widget Function(BuildContext context, bool isDesktop) builder;
  final SidebarItem? active;
  final Widget? leftPanel;
  final double leftPanelWidth;
  final Widget? rightPanel;
  final double rightPanelWidth;
  final double contentMaxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= kDesktopBreakpoint;
        final content = builder(context, isDesktop);
        if (!isDesktop) return content;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSidebar(active: active),
            if (leftPanel != null) SizedBox(width: leftPanelWidth, child: leftPanel),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: content,
                ),
              ),
            ),
            if (rightPanel != null) SizedBox(width: rightPanelWidth, child: rightPanel),
          ],
        );
      },
    );
  }
}
