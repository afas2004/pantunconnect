import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neomorphic_box.dart';

/// Mirrors ui/screens/settings/SettingsScreen.kt (Exhibit 10), minus the dark-mode toggle
/// (removed by request - the app is light-theme only now) and plus a Sign Out entry (moved
/// here from the Profile screen's app bar).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.onBack, required this.onLogout});

  final VoidCallback onBack;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
      ),
      body: Container(
        color: AppColors.warmWhite,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('App Settings', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 20),
            const _SettingsItem(icon: Icons.notifications, title: 'Notifications', description: 'Manage alert sounds and frequency'),
            const SizedBox(height: 20),
            const _SettingsItem(icon: Icons.security, title: 'Privacy & Safety', description: 'Control who sees your posts'),
            const SizedBox(height: 20),
            const Text('Account', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                );
                if (confirmed != true || !context.mounted) return;
                await context.read<AuthProvider>().logout();
                onLogout();
              },
              child: const _SettingsItem(
                icon: Icons.logout,
                title: 'Sign Out',
                description: 'Log out of your account on this device',
                iconColor: Colors.redAccent,
              ),
            ),
            const Spacer(),
            const Center(child: Text('PANTUN-CONNECT v1.0.0', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Mirrors SettingsScreen.kt's `SettingsItem` composable (icon in a tinted rounded surface).
class _SettingsItem extends StatelessWidget {
  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.description,
    this.iconColor = AppColors.primaryAccentStrong,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return NeomorphicBox(
      backgroundColor: Colors.white,
      borderRadius: 24,
      elevation: 4,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(description, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
