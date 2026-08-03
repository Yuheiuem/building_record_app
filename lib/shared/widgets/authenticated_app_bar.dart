import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/routing/app_routes.dart';
import '../../data/services/auth_service.dart';

class AuthenticatedAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const AuthenticatedAppBar({
    required this.authService,
    required this.title,
    this.showHomeAction = true,
    this.showVersion = false,
    super.key,
  });

  final AuthService authService;
  final String title;
  final bool showHomeAction;
  final bool showVersion;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);

  @override
  Widget build(BuildContext context) {
    final TextStyle? versionStyle = Theme.of(context).textTheme.labelSmall
        ?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        );

    return AppBar(
      title: showVersion
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title),
                Text(AppConfig.version, style: versionStyle),
              ],
            )
          : Text(title),
      actions: <Widget>[
        if (showHomeAction)
          IconButton(
            onPressed: () => context.go(AppRoutes.home),
            tooltip: 'ホーム',
            icon: const Icon(Icons.home_outlined),
          ),
        IconButton(
          onPressed: () => unawaited(authService.signOut()),
          tooltip: 'ログアウト',
          icon: const Icon(Icons.logout_outlined),
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(
          height: 1,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }
}

class AppVersionFooter extends StatelessWidget {
  const AppVersionFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      '${AppConfig.stage} / ${AppConfig.version}',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
