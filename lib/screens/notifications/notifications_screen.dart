import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/notifications_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neomorphic_box.dart';

/// Mirrors ui/screens/notifications/NotificationsScreen.kt exactly, including the type-based
/// icon/color per notification (like=pink, comment=blue, follow=green).
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationsProvider>();

    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.softBlue))
          : provider.notifications.isEmpty
              ? const Center(child: Text('No notifications yet', style: TextStyle(color: AppColors.textSecondary)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _NotificationCard(
                    notification: provider.notifications[i],
                    onTap: () => provider.markAsRead(provider.notifications[i].id),
                  ),
                ),
    );
  }
}

/// Mirrors NotificationsScreen.kt's `NotificationCard` composable.
class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color iconColor;
    switch (notification.type) {
      case 'like':
        icon = Icons.favorite;
        iconColor = AppColors.pastelPinkStrong;
        break;
      case 'comment':
        icon = Icons.message;
        iconColor = AppColors.primaryAccentStrong;
        break;
      case 'follow':
        icon = Icons.person_add;
        iconColor = AppColors.mintGreenStrong;
        break;
      default:
        icon = Icons.message;
        iconColor = AppColors.textSecondary;
    }

    // NeomorphicBox paints its own opaque background/shadow, so a plain InkWell around it would
    // have its ripple hidden underneath. Stacking a transparent InkWell on top (same border
    // radius) instead lets the ripple/highlight paint visibly over the card on tap, matching the
    // notification's own accent color rather than the default grey Material ripple.
    return Stack(
      children: [
        NeomorphicBox(
          backgroundColor: Colors.white,
          borderRadius: 16,
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: iconColor.withOpacity(0.2), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.message,
                        style: TextStyle(fontSize: 14, fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold),
                      ),
                      Text(
                        DateFormat('MMM dd, HH:mm').format(DateTime.fromMillisecondsSinceEpoch(notification.timestamp)),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              splashColor: iconColor.withOpacity(0.25),
              highlightColor: iconColor.withOpacity(0.1),
            ),
          ),
        ),
      ],
    );
  }
}
