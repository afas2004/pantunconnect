import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/chat_list_provider.dart';
import '../providers/create_pantun_provider.dart';
import '../providers/edit_profile_provider.dart';
import '../providers/notifications_provider.dart';
import '../providers/user_connections_provider.dart';
import '../providers/user_profile_provider.dart';
import '../repositories/chat_repository.dart';
import '../repositories/post_repository.dart';
import '../repositories/storage_repository.dart';
import '../repositories/user_repository.dart';
import '../services/draft_service.dart';
import '../services/gemini_service.dart';
import '../services/preference_service.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/desktop_page_shell.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/chat/chat_list_screen.dart';
import '../screens/chat/messaging_screen.dart';
import '../screens/connections/user_connections_screen.dart';
import '../screens/create/create_pantun_screen.dart';
import '../screens/main_shell.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/post_detail/post_detail_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/profile/user_profile_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/splash/splash_screen.dart';

/// Mirrors ui/navigation/Screen.kt + the NavHost in MainActivity.kt.
///
/// Each route that had a per-screen ViewModel in the Kotlin app (via `hiltViewModel()`) is
/// wrapped here with its own `ChangeNotifierProvider`, giving it a fresh provider instance per
/// visit - the same scoping Hilt gave those ViewModels. App-wide singletons (repositories,
/// services, AuthProvider) are provided once in main.dart instead.
GoRouter buildAppRouter() {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => SplashScreen(
          onSplashFinished: (isLoggedIn) async {
            if (isLoggedIn) {
              context.go('/home');
            } else {
              final completedOnboarding = await PreferenceService().hasCompletedOnboarding();
              context.go(completedOnboarding ? '/login' : '/onboarding');
            }
          },
        ),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => OnboardingScreen(
          onFinish: () async {
            await PreferenceService().setOnboardingCompleted(true);
            if (context.mounted) context.go('/login');
          },
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(
          // push (not go) so Register's and Forgot Password's "back"/"Login" links have
          // something to pop back to - go() replaces the stack, leaving pop() with nothing to
          // return to, which was silently breaking both of those links.
          onNavigateToRegister: () => context.push('/register'),
          onNavigateToForgotPassword: () => context.push('/forgot-password'),
          onLoginSuccess: () => context.go('/home'),
        ),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => RegisterScreen(
          onNavigateToLogin: () => context.pop(),
          onRegisterSuccess: () => context.go('/home'),
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => ForgotPasswordScreen(onBack: () => context.pop()),
      ),
      GoRoute(
        // The four main destinations (Home / Search / AI / Profile) live inside MainShell as
        // persistent tabs with a shared bottom nav - not as separate pushed routes. `?tab=` lets
        // the desktop sidebar on OTHER screens (Post Detail, Settings, ...) land on a specific
        // tab, since there's no other way to address one from outside MainShell.
        path: '/home',
        builder: (context, state) {
          final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0;
          return MainShell(initialTab: tab);
        },
      ),
      GoRoute(
        path: '/create-pantun',
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) => CreatePantunProvider(
            context.read<PostRepository>(),
            context.read<StorageRepository>(),
            context.read<GeminiService>(),
            context.read<DraftService>(),
            FirebaseAuth.instance,
          ),
          child: CreatePantunScreen(onBack: () => context.pop(), onSuccess: () => context.pop()),
        ),
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) => EditProfileProvider(
            context.read<UserRepository>(),
            context.read<StorageRepository>(),
            FirebaseAuth.instance,
          ),
          child: EditProfileScreen(onBack: () => context.pop()),
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => DesktopPageShell(
          active: SidebarItem.profile,
          builder: (context, isDesktop) => SettingsScreen(
            onBack: () => context.pop(),
            onLogout: () => context.go('/login'),
          ),
        ),
      ),
      GoRoute(
        path: '/chat-list',
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) => ChatListProvider(context.read<ChatRepository>(), context.read<UserRepository>(), FirebaseAuth.instance),
          child: ChatListScreen(
            onBack: () => context.pop(),
            onNavigateToChat: (chatId) => context.push('/messaging/$chatId'),
            onNavigateToNewChat: (userId) => context.push('/connections/$userId/following'),
          ),
        ),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) => NotificationsProvider(FirebaseFirestore.instance, FirebaseAuth.instance),
          child: NotificationsScreen(onBack: () => context.pop()),
        ),
      ),
      GoRoute(
        // No chatId - the desktop sidebar's "Messages" item lands here directly (see
        // AppSidebar), showing the conversations rail with nothing selected yet. MessagingScreen
        // treats an empty chatId as "no conversation open" and skips creating a MessagingProvider.
        path: '/messaging',
        builder: (context, state) => const MessagingScreen(chatId: '', onBack: null),
      ),
      GoRoute(
        path: '/messaging/:chatId',
        builder: (context, state) => MessagingScreen(
          chatId: state.pathParameters['chatId'] ?? '',
          onBack: () => context.pop(),
        ),
      ),
      GoRoute(
        path: '/connections/:userId/:tab',
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) => UserConnectionsProvider(context.read<UserRepository>(), context.read<ChatRepository>(), FirebaseAuth.instance),
          child: UserConnectionsScreen(
            userId: state.pathParameters['userId'] ?? '',
            initialTab: state.pathParameters['tab'] ?? 'following',
            onBack: () => context.pop(),
            onNavigateToChat: (chatId) => context.push('/messaging/$chatId'),
            onNavigateToProfile: (userId) => context.push('/user/$userId'),
          ),
        ),
      ),
      GoRoute(
        path: '/user/:userId',
        builder: (context, state) {
          final userId = state.pathParameters['userId'] ?? '';
          return ChangeNotifierProvider(
            create: (context) => UserProfileProvider(
              context.read<UserRepository>(),
              context.read<PostRepository>(),
              context.read<ChatRepository>(),
              FirebaseAuth.instance,
              userId,
            ),
            child: UserProfileScreen(
              onBack: () => context.pop(),
              onNavigateToChat: (chatId) => context.push('/messaging/$chatId'),
              onNavigateToPostDetail: (postId) => context.push('/post/$postId'),
              onNavigateToFollowers: (id) => context.push('/connections/$id/followers'),
              onNavigateToFollowing: (id) => context.push('/connections/$id/following'),
            ),
          );
        },
      ),
      GoRoute(
        path: '/post/:postId',
        builder: (context, state) => PostDetailScreen(
          postId: state.pathParameters['postId'] ?? '',
          onBack: () => context.pop(),
          onNavigateToUserProfile: (userId) => context.push('/user/$userId'),
        ),
      ),
    ],
  );
}
