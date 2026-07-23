import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/services/auth_service.dart';
import '../../features/auth/presentation/sign_in_page.dart';
import '../../features/browse/presentation/browse_page.dart';
import '../../features/diagnostics/presentation/diagnostics_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/record/presentation/record_page.dart';
import 'app_routes.dart';

GoRouter createAppRouter({
  required AuthService authService,
  String? initialLocation,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: authService,
    redirect: (BuildContext context, GoRouterState state) {
      final String path = state.uri.path;
      final GoogleAuthStatus status = authService.status;

      if (status == GoogleAuthStatus.initializing) {
        return path == AppRoutes.loading ? null : AppRoutes.loading;
      }

      final bool isSignedIn = status == GoogleAuthStatus.signedIn;
      final bool isPublicRoute =
          path == AppRoutes.signIn || path == AppRoutes.loading;

      if (!isSignedIn) {
        if (path == AppRoutes.signIn) {
          return null;
        }

        final String from = path == AppRoutes.loading
            ? AppRoutes.home
            : state.uri.toString();
        return Uri(
          path: AppRoutes.signIn,
          queryParameters: <String, String>{'from': from},
        ).toString();
      }

      if (isPublicRoute) {
        final String? requestedPath = state.uri.queryParameters['from'];
        if (requestedPath != null && requestedPath.startsWith('/')) {
          return requestedPath;
        }
        return AppRoutes.home;
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.loading,
        builder: (BuildContext context, GoRouterState state) {
          return const _AuthenticationLoadingPage();
        },
      ),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (BuildContext context, GoRouterState state) {
          return SignInPage(authService: authService);
        },
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (BuildContext context, GoRouterState state) {
          return HomePage(authService: authService);
        },
      ),
      GoRoute(
        path: AppRoutes.record,
        builder: (BuildContext context, GoRouterState state) {
          return RecordPage(authService: authService);
        },
      ),
      GoRoute(
        path: AppRoutes.browse,
        builder: (BuildContext context, GoRouterState state) {
          return BrowsePage(authService: authService);
        },
      ),
      GoRoute(
        path: AppRoutes.diagnostics,
        builder: (BuildContext context, GoRouterState state) {
          return DiagnosticsPage(authService: authService);
        },
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) {
      return _RouteNotFoundPage(requestedUri: state.uri);
    },
  );
}

class _AuthenticationLoadingPage extends StatelessWidget {
  const _AuthenticationLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('ログイン状態を確認しています。'),
          ],
        ),
      ),
    );
  }
}

class _RouteNotFoundPage extends StatelessWidget {
  const _RouteNotFoundPage({required this.requestedUri});

  final Uri requestedUri;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ページが見つかりません')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.search_off_outlined, size: 56),
              const SizedBox(height: 16),
              Text(
                requestedUri.path,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => context.go(AppRoutes.home),
                icon: const Icon(Icons.home_outlined),
                label: const Text('ホームへ戻る'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
