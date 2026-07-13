import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/google_auth_service.dart';
import 'google_sign_in_button.dart';

class AuthSpikePage extends StatefulWidget {
  const AuthSpikePage({super.key, this.authService});

  final AuthService? authService;

  @override
  State<AuthSpikePage> createState() => _AuthSpikePageState();
}

class _AuthSpikePageState extends State<AuthSpikePage> {
  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? GoogleAuthService.instance;
    _authService.addListener(_handleAuthChanged);
    unawaited(_authService.initialize());
  }

  void _handleAuthChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _authService.removeListener(_handleAuthChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _AppHeader(),
                  const SizedBox(height: 24),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Googleログイン確認',
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '専用Googleアカウントでログインし、'
                            'IDトークンを取得できることを確認します。'
                            'Apps ScriptとDriveにはまだ接続しません。',
                            style: textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 24),
                          const _StatusRow(
                            icon: Icons.web_asset_outlined,
                            label: 'Flutter Web・GitHub Pages',
                            status: '準備完了',
                            completed: true,
                          ),
                          const Divider(height: 32),
                          const _StatusRow(
                            icon: Icons.admin_panel_settings_outlined,
                            label: 'Google OAuth設定',
                            status: '設定済み',
                            completed: true,
                          ),
                          const Divider(height: 32),
                          _StatusRow(
                            icon: Icons.account_circle_outlined,
                            label: 'Googleログイン',
                            status: _loginStatusText,
                            completed:
                                _authService.status ==
                                GoogleAuthStatus.signedIn,
                          ),
                          const Divider(height: 32),
                          _StatusRow(
                            icon: Icons.key_outlined,
                            label: 'IDトークン',
                            status: _tokenStatusText,
                            completed: _authService.hasIdToken,
                          ),
                          const SizedBox(height: 24),
                          _AuthActionPanel(authService: _authService),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'IDトークン本文は画面・ログ・GitHubへ出力しません。',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppConfig.version,
                    textAlign: TextAlign.center,
                    style: textTheme.labelLarge,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _loginStatusText {
    return switch (_authService.status) {
      GoogleAuthStatus.initializing => '初期化中',
      GoogleAuthStatus.signedOut => '未ログイン',
      GoogleAuthStatus.signedIn => 'ログイン済み',
      GoogleAuthStatus.error => 'エラー',
    };
  }

  String get _tokenStatusText {
    if (_authService.hasIdToken) {
      return '取得済み';
    }

    return _authService.status == GoogleAuthStatus.initializing ? '確認中' : '未取得';
  }
}

class _AuthActionPanel extends StatelessWidget {
  const _AuthActionPanel({required this.authService});

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = <Widget>[];
    final String? errorMessage = authService.errorMessage;

    if (errorMessage != null) {
      children.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            errorMessage,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
        ),
      );
      children.add(const SizedBox(height: 16));
    }

    children.add(switch (authService.status) {
      GoogleAuthStatus.initializing => const _InitializingPanel(),
      GoogleAuthStatus.signedOut => const _SignedOutPanel(),
      GoogleAuthStatus.signedIn => _SignedInPanel(authService: authService),
      GoogleAuthStatus.error => const _SignedOutPanel(),
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _InitializingPanel extends StatelessWidget {
  const _InitializingPanel();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 12),
        Text('Googleログインを初期化しています。'),
      ],
    );
  }
}

class _SignedOutPanel extends StatelessWidget {
  const _SignedOutPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          '専用Googleアカウントを選択してください。',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Center(child: buildGoogleSignInButton()),
      ],
    );
  }
}

class _SignedInPanel extends StatelessWidget {
  const _SignedInPanel({required this.authService});

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    final AuthenticatedGoogleUser? user = authService.currentUser;
    final String displayName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!
        : 'Googleアカウント';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  Icons.person_outline,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SelectableText(user?.email ?? ''),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Icon(
                authService.hasIdToken
                    ? Icons.check_circle
                    : Icons.error_outline,
                size: 18,
                color: authService.hasIdToken
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  authService.hasIdToken
                      ? 'IDトークンを取得できました。'
                      : 'IDトークンを取得できませんでした。',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: authService.signOut,
              icon: const Icon(Icons.logout),
              label: const Text('ログアウト'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader();

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Icon(
              Icons.apartment_outlined,
              size: 32,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                AppConfig.workingTitle,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppConfig.stage,
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.status,
    required this.completed,
  });

  final IconData icon;
  final String label;
  final String status;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Color statusColor = completed
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
        ),
        const SizedBox(width: 12),
        Semantics(
          label: '$label: $status',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                completed ? Icons.check_circle : Icons.schedule,
                size: 18,
                color: statusColor,
              ),
              const SizedBox(width: 6),
              Text(
                status,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
