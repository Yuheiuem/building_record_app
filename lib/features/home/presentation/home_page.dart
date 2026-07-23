import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/routing/app_routes.dart';
import '../../../data/services/auth_service.dart';
import '../../../shared/widgets/authenticated_app_bar.dart';

class HomePage extends StatelessWidget {
  const HomePage({required this.authService, super.key});

  static const double compactBreakpoint = 720;

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConfig.workingTitle),
        actions: <Widget>[
          IconButton(
            onPressed: () => unawaited(authService.signOut()),
            tooltip: 'ログアウト',
            icon: const Icon(Icons.logout_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool isCompact = constraints.maxWidth < compactBreakpoint;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 16 : 32,
                vertical: 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _WelcomeHeader(authService: authService),
                      const SizedBox(height: 24),
                      if (isCompact)
                        const _CompactActionLayout()
                      else
                        const _WideActionLayout(),
                      const SizedBox(height: 24),
                      const AppVersionFooter(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.authService});

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    final AuthenticatedGoogleUser? user = authService.currentUser;
    final String displayName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!
        : '利用者';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '$displayNameさん',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          '記録するか、これまでの建築を振り返るかを選んでください。',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _CompactActionLayout extends StatelessWidget {
  const _CompactActionLayout();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _HomeActionCard(
          key: Key('primary-record-action'),
          icon: Icons.add_a_photo_outlined,
          title: '建築を記録する',
          description: '写真・位置・メモを登録します。',
          route: AppRoutes.record,
          emphasized: true,
        ),
        SizedBox(height: 16),
        _HomeActionCard(
          icon: Icons.map_outlined,
          title: '地図・一覧で見る',
          description: '登録した建築を地図や一覧で探します。',
          route: AppRoutes.browse,
        ),
        SizedBox(height: 16),
        _DiagnosticsActionCard(),
      ],
    );
  }
}

class _WideActionLayout extends StatelessWidget {
  const _WideActionLayout();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: <Widget>[
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                flex: 2,
                child: _HomeActionCard(
                  key: Key('primary-browse-action'),
                  icon: Icons.map_outlined,
                  title: '地図・一覧で見る',
                  description: '登録した建築を地図と一覧から探し、詳細や訪問履歴を確認します。',
                  route: AppRoutes.browse,
                  emphasized: true,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _HomeActionCard(
                  icon: Icons.add_a_photo_outlined,
                  title: '建築を記録する',
                  description: '写真・位置・メモを登録します。',
                  route: AppRoutes.record,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        _DiagnosticsActionCard(),
      ],
    );
  }
}

class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.route,
    this.emphasized = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final String route;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: emphasized ? colorScheme.primaryContainer : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(route),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                icon,
                size: emphasized ? 42 : 34,
                color: emphasized
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: emphasized ? colorScheme.onPrimaryContainer : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: emphasized
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.arrow_forward,
                  color: emphasized
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiagnosticsActionCard extends StatelessWidget {
  const _DiagnosticsActionCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: () => context.go(AppRoutes.diagnostics),
        leading: const Icon(Icons.science_outlined),
        title: const Text('技術診断を開く'),
        subtitle: const Text('Googleログイン・Apps Script・非公開Drive保存を確認します。'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
