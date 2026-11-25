import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../features/auth/presentation/complete_profile_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/group_expenses/presentation/add_group_expense_screen.dart';
import '../../features/groups/presentation/group_detail_screen.dart';
import '../../features/groups/presentation/groups_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/loans/presentation/loans_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/personal_finance/presentation/personal_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/providers/profile_provider.dart';
import '../constants/app_icons.dart';
import '../l10n/app_localizations.dart';
import '../services/connectivity_provider.dart';
import '../widgets/floating_nav_bar.dart';
import 'route_names.dart';

class _RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier();

  ref.listen(internetStatusProvider, (_, _) => refreshNotifier.refresh());
  ref.listen(currentUserProvider, (_, _) => refreshNotifier.refresh());
  ref.listen(currentProfileProvider, (_, _) => refreshNotifier.refresh());
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: RoutePaths.splash,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final internetAsync = ref.read(internetStatusProvider);
      if (internetAsync.isLoading || internetAsync.valueOrNull != true) {
        return loc == RoutePaths.splash ? null : RoutePaths.splash;
      }

      final isAuthRoute = loc == RoutePaths.login ||
          loc == RoutePaths.register ||
          loc == RoutePaths.forgotPassword;

      final user = ref.read(currentUserProvider);
      if (user == null) {
        return isAuthRoute ? null : RoutePaths.login;
      }

      final profileAsync = ref.read(currentProfileProvider);
      if (profileAsync.isLoading || profileAsync.hasError) return null;

      final profile = profileAsync.valueOrNull;
      final completed = profile?.profileCompleted ?? false;

      if (!completed) {
        return loc == RoutePaths.completeProfile
            ? null
            : RoutePaths.completeProfile;
      }

      if (isAuthRoute ||
          loc == RoutePaths.completeProfile ||
          loc == RoutePaths.splash) {
        return RoutePaths.home;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: RoutePaths.splash,
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.login,
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(
        path: RoutePaths.register,
        builder: (_, _) => const RegisterScreen(),
      ),
      GoRoute(
        path: RoutePaths.forgotPassword,
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: RoutePaths.completeProfile,
        builder: (_, _) => const CompleteProfileScreen(),
      ),
      GoRoute(
        path: RoutePaths.notifications,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: RoutePaths.loans,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const LoansScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _MainShellScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.home,
                builder: (_, _) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.groups,
                builder: (_, _) => const GroupsScreen(),
                routes: [
                  GoRoute(
                    path: ':groupId',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, state) => GroupDetailScreen(
                      groupId: state.pathParameters['groupId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'add-expense',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (_, state) => AddGroupExpenseScreen(
                          groupId: state.pathParameters['groupId']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.personal,
                builder: (_, _) => const PersonalScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.profile,
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _MainShellScaffold extends StatelessWidget {
  const _MainShellScaffold({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: FloatingNavBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        items: [
          FloatingNavItem(icon: AppIcons.layoutGrid, label: l10n.t('nav_home')),
          FloatingNavItem(icon: AppIcons.users, label: l10n.t('nav_groups')),
          FloatingNavItem(icon: AppIcons.wallet, label: l10n.t('nav_personal')),
          FloatingNavItem(icon: AppIcons.user, label: l10n.t('nav_profile')),
        ],
      ),
    );
  }
}
