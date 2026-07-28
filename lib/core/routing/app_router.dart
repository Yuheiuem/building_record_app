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

      // 認証初期化中は、現在開こうとしているURLをfromへ保持する。
      if (status == GoogleAuthStatus.initializing) {
        if (path == AppRoutes.loading) {
          return null;
        }

        final String requestedLocation = _requestedLocation(state);

        return Uri(
          path: AppRoutes.loading,
          queryParameters: <String, String>{
            'from': requestedLocation,
          },
        ).toString();
      }

      final bool isSignedIn = status == GoogleAuthStatus.signedIn;
      final bool isPublicRoute =
          path == AppRoutes.signIn || path == AppRoutes.loading;

      if (!isSignedIn) {
        if (path == AppRoutes.signIn) {
          return null;
        }

        final String requestedLocation = _requestedLocation(state);

        return Uri(
          path: AppRoutes.signIn,
          queryParameters: <String, String>{
            'from': requestedLocation,
          },
        ).toString();
      }

      if (isPublicRoute) {
        return _requestedLocation(state);
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

/// 認証初期化やログイン画面を挟んでも、元々開こうとしたURLを返す。
String _requestedLocation(GoRouterState state) {
  final String? from = state.uri.queryParameters['from'];

  if (_isRestorableLocation(from)) {
    return from!;
  }

  final String currentLocation = state.uri.toString();

  if (_isRestorableLocation(currentLocation)) {
    return currentLocation;
  }

  return AppRoutes.home;
}

/// loadingとsign-in自体は復帰先にしない。
bool _isRestorableLocation(String? location) {
  if (location == null || !location.startsWith('/')) {
    return false;
  }

  final Uri? uri = Uri.tryParse(location);

  if (uri == null) {
    return false;
  }

  return uri.path != AppRoutes.loading && uri.path != AppRoutes.signIn;
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
  const _RouteNotFoundPage({
    required this.requestedUri,
  });

  final Uri requestedUri;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ページが見つかりません'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.search_off_outlined,
                size: 56,
              ),
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