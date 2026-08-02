import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Mirrors ui/screens/onboarding/OnboardingScreen.kt exactly: a single static screen (no paging,
/// no carousel) with a headline, a description, and one "Get Started" button.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, required this.onFinish});

  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Modern Pantun for a New Generation',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primaryAccentStrong),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Connect with the beauty of Malay culture through AI-assisted poetry and community sharing.',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 64),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: onFinish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAccentStrong,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Get Started', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
