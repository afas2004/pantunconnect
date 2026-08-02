import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/preference_service.dart';
import '../../theme/app_theme.dart';

/// Mirrors ui/screens/splash/SplashScreen.kt exactly: "PANTUN" (48sp ExtraBold, SoftBlue) fades
/// in over the text "CONNECT" (24sp Light, Gray, 4sp letter-spacing) on a WarmWhite background,
/// over a 1500ms fade-in, then a further 1000ms delay before deciding where to navigate.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onSplashFinished});

  /// Called with true if the user is already logged in, false otherwise.
  final void Function(bool isLoggedIn) onSplashFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  late final Animation<double> _alpha = CurvedAnimation(parent: _controller, curve: Curves.linear);

  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    await _controller.forward();
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    // try/catch mirrors the Kotlin SplashScreen and, crucially, guarantees onSplashFinished is
    // ALWAYS called: if Firebase failed to initialize in main(), FirebaseAuth.instance throws,
    // and without the catch the app would sit on the splash screen forever.
    bool isLoggedIn;
    try {
      isLoggedIn = FirebaseAuth.instance.currentUser != null;
    } catch (_) {
      isLoggedIn = false;
    }
    widget.onSplashFinished(isLoggedIn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      body: Center(
        child: FadeTransition(
          opacity: _alpha,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              Text(
                'PANTUN',
                style: TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: AppColors.primaryAccentStrong),
              ),
              Text(
                'CONNECT',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textSecondary,
                  letterSpacing: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// Reads onboarding-completion status; used by the router to decide Login vs Onboarding.
Future<bool> hasCompletedOnboarding() => PreferenceService().hasCompletedOnboarding();
