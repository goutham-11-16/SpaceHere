import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/auth/auth_screen.dart';
import '../../features/auth/telegram_verification_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/storage/folder_view_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final isLoading = auth.isLoading && !auth.hasValue;
      if (isLoading) {
        return null;
      }

      final isAuthenticated = auth.asData?.value.isAuthenticated ?? false;
      final location = state.matchedLocation;
      final isAuthRoute = location == '/login' || location == '/telegram_otp';

      if (!isAuthenticated && !isAuthRoute) {
        return '/login';
      }

      if (isAuthenticated &&
          (location == '/login' || location == '/telegram_otp')) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const AuthScreen()),
      GoRoute(
        path: '/telegram_otp',
        builder: (context, state) {
          return TelegramVerificationScreen(extra: state.extra);
        },
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/folder/:uuid',
        builder: (context, state) {
          final uuid = state.pathParameters['uuid'];
          return FolderViewScreen(parentUuid: uuid == 'root' ? null : uuid);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
