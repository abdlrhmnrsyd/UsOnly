import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/domain/auth_state.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/chat/presentation/chat_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/home/presentation/main_shell_screen.dart';
import '../features/memories/presentation/create_memory_screen.dart';
import '../features/memories/presentation/memories_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/pairing/presentation/connection_success_screen.dart';
import '../features/pairing/presentation/create_code_screen.dart';
import '../features/pairing/presentation/enter_code_screen.dart';
import '../features/pairing/presentation/pairing_onboarding_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/tracking/presentation/location_tracking_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'rootNav');
final _homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'homeNav');
final _chatNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'chatNav');
final _trackingNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'trackingNav');
final _memoriesNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'memoriesNav');
final _profileNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'profileNav');

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(
      authStateProvider,
      (previous, next) => notifyListeners(),
    );
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/auth/login',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isAuth = authState.status == AuthStatus.authenticated && authState.user != null;
      final location = state.matchedLocation;
      final isAuthRoute = location.startsWith('/auth');
      final isPairingRoute = location.startsWith('/pairing');
      final isSuccessRoute = location == '/pairing/success';

      // 1. Loading / Initial check: don't prematurely redirect while checking state
      if (authState.status == AuthStatus.initial || authState.status == AuthStatus.loading) {
        return null;
      }

      // 2. Unauthenticated: restrict entirely to /auth routes
      if (!isAuth) {
        return isAuthRoute ? null : '/auth/login';
      }

      // 3. Authenticated: verify couple pairing status
      final hasCouple = authState.user!.coupleId != null && authState.user!.coupleId!.isNotEmpty;

      if (!hasCouple) {
        // Unpaired user cannot access main shell or auth
        // They must stay on pairing flow
        if (isPairingRoute) return null;
        return '/pairing';
      }

      // 4. Paired user: keep out of auth & pairing (allow /pairing/success if currently transitioning)
      if (isSuccessRoute) return null;
      if (isAuthRoute || isPairingRoute) {
        return '/home';
      }

      return null;
    },
    routes: [
      // Authentication Routes
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // Pairing Flow Routes (Blocked from chat before pairing)
      GoRoute(
        path: '/pairing',
        builder: (context, state) => const PairingOnboardingScreen(),
        routes: [
          GoRoute(
            path: 'create',
            builder: (context, state) => const CreateCodeScreen(),
          ),
          GoRoute(
            path: 'enter',
            builder: (context, state) => const EnterCodeScreen(),
          ),
          GoRoute(
            path: 'success',
            builder: (context, state) => const ConnectionSuccessScreen(),
          ),
        ],
      ),

      // Notification Center Route
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),

      // Main App Shell with Bottom Navigation (Home, Chat, Radar, Memories, Profile)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShellScreen(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Home
          StatefulShellBranch(
            navigatorKey: _homeNavigatorKey,
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),

          // Branch 1: Chat
          StatefulShellBranch(
            navigatorKey: _chatNavigatorKey,
            routes: [
              GoRoute(
                path: '/chat',
                builder: (context, state) => const ChatScreen(),
              ),
            ],
          ),

          // Branch 2: Radar & Live Tracking
          StatefulShellBranch(
            navigatorKey: _trackingNavigatorKey,
            routes: [
              GoRoute(
                path: '/tracking',
                builder: (context, state) => const LocationTrackingScreen(),
              ),
            ],
          ),

          // Branch 3: Memories & Timeline
          StatefulShellBranch(
            navigatorKey: _memoriesNavigatorKey,
            routes: [
              GoRoute(
                path: '/memories',
                builder: (context, state) => const MemoriesScreen(),
                routes: [
                  GoRoute(
                    path: 'create',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const CreateMemoryScreen(),
                  ),
                ],
              ),
            ],
          ),

          // Branch 4: Profile & Settings
          StatefulShellBranch(
            navigatorKey: _profileNavigatorKey,
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
