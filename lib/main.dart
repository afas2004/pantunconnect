import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'repositories/auth_repository.dart';
import 'repositories/chat_repository.dart';
import 'repositories/post_repository.dart';
import 'repositories/storage_repository.dart';
import 'repositories/user_repository.dart';
import 'routing/app_router.dart';
import 'services/draft_service.dart';
import 'services/gemini_service.dart';
import 'services/preference_service.dart';
import 'theme/app_theme.dart';

/// Mirrors PantunConnectApp.kt (the Hilt Application class) + MainActivity.kt's
/// composition root. Repositories/services and AuthProvider are provided once
/// here as app-wide singletons (matching Hilt's @Singleton scope); everything else is provided
/// per-route inside app_router.dart (matching hiltViewModel()'s per-screen scoping).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Temporary startup logging + a hard timeout on Firebase init: a bare `await
  // Firebase.initializeApp()` with no timeout means that if the native side ever hangs (no
  // network on the emulator, a stuck platform channel, etc.) instead of throwing, runApp() never
  // gets called and the app is stuck on the native launch screen forever with no error visible
  // anywhere. Logging + a timeout turns "stuck at the Flutter logo with zero information" into
  // either a fast, visible failure or a console line pinpointing exactly what's slow.
  debugPrint('[startup] WidgetsFlutterBinding ready. Initializing Firebase...');
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
        .timeout(const Duration(seconds: 15));
    debugPrint('[startup] Firebase initialized OK.');
  } catch (e, st) {
    debugPrint('[startup] Firebase.initializeApp FAILED or timed out: $e');
    debugPrint('[startup] $st');
    // Continue anyway - screens that touch Firebase (login, feed, etc.) will surface their own
    // error states instead of the whole app being stuck on the launch screen forever.
  }

  try {
    await Hive.initFlutter();
    debugPrint('[startup] Hive initialized OK.');
  } catch (e) {
    debugPrint('[startup] Hive.initFlutter FAILED: $e');
  }

  // Picks up the result of a signInWithRedirect() Google sign-in from before this reload (web
  // only, no-op everywhere else) - see auth_repository.dart's signInWithGoogle() for why redirect
  // replaced the old popup flow. Deliberately NOT awaited: this only matters on the one reload
  // right after a Google sign-in redirect, and SplashScreen's own ~2.5s fade-in already gives it
  // plenty of time to finish in the background before it checks
  // FirebaseAuth.instance.currentUser - awaiting here would instead delay every single app
  // launch by up to 10s for a case that applies to almost none of them.
  AuthRepository().completeGoogleRedirectSignIn().timeout(const Duration(seconds: 10)).then(
        (_) => debugPrint('[startup] completeGoogleRedirectSignIn() done.'),
        onError: (e) => debugPrint('[startup] completeGoogleRedirectSignIn() FAILED or timed out: $e'),
      );

  debugPrint('[startup] calling runApp()...');
  runApp(const PantunConnectApp());
}

class PantunConnectApp extends StatefulWidget {
  const PantunConnectApp({super.key});

  @override
  State<PantunConnectApp> createState() => _PantunConnectAppState();
}

class _PantunConnectAppState extends State<PantunConnectApp> {
  // Built once - rebuilding on every widget rebuild would create a brand new GoRouter/Navigator
  // and wipe the back stack.
  late final _router = buildAppRouter();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Repositories / services - app-wide singletons.
        Provider<AuthRepository>(create: (_) => AuthRepository()),
        Provider<UserRepository>(create: (_) => UserRepository()),
        Provider<PostRepository>(create: (_) => PostRepository()),
        Provider<ChatRepository>(create: (_) => ChatRepository()),
        Provider<StorageRepository>(create: (_) => StorageRepository()),
        Provider<GeminiService>(create: (_) => GeminiService()),
        Provider<PreferenceService>(create: (_) => PreferenceService()),
        Provider<DraftService>(create: (_) => DraftService()),

        // App-wide state.
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(context.read<AuthRepository>()),
        ),
      ],
      // Light theme only - dark mode (and its Settings toggle) removed by request.
      child: MaterialApp.router(
        title: 'PANTUN-CONNECT',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: _router,
      ),
    );
  }
}
