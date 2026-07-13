import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../data/models/health_check_response.dart';
import '../../../data/services/apps_script_api_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/google_auth_service.dart';
import 'google_sign_in_button.dart';

class AuthSpikePage extends StatefulWidget {
  const AuthSpikePage({
    super.key,
    this.authService,
    this.appsScriptApiService,
  });

  final AuthService? authService;
  final AppsScriptApiService? appsScriptApiService;

  @override
  State<AuthSpikePage> createState() => _AuthSpikePageState();
}

class _AuthSpikePageState extends State<AuthSpikePage> {
  late final AuthService _authService;
  late final AppsScriptApiService _appsScriptApiService;
  late final bool _ownsAppsScriptApiService;

  _HealthCheckStatus _healthCheckStatus = _HealthCheckStatus.notRun;
  HealthCheckResponse? _healthCheckResponse;
  String? _healthCheckError;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? GoogleAuthService.instance;
    _authService.addListener(_handleAuthChanged);
    unawaited(_authService.initialize());

    _ownsAppsScriptApiService = widget.appsScriptApiService == null;
    _appsScriptApiService =
        widget.appsScriptApiService ?? HttpAppsScriptApiService();
  }

  void _handleAuthChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _runHealthCheck() async {
    if (_healthCheckStatus == _HealthCheckStatus.running) {
      return;
    }

    setState(() {
      _healthCheckStatus = _HealthCheckStatus.running;
      _healthCheckResponse = null;
      _healthCheckError = null;
    });

    try {
      final HealthCheckResponse response =
          await _appsScriptApiService.healthCheck(
        requestId: Uuid().v4(),
        clientVersion: AppConfig.version,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _healthCheckResponse = response;
        _healthCheckStatus = response.isHealthy
            ? _HealthCheckStatus.success
            : _HealthCheckStatus.error;
        _healthCheckError = response.isHealthy
            ? null
            : response.message ?? 'healthCheckの結果が正常ではありません。';
      });
    } on AppsScriptApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _healthCheckStatus = _HealthCheckStatus.error;
        _healthCheckError = error.message;
      });
    } on Object {
      if (!mounted) {
        return;
      }

      setState(() {
        _healthCheckStatus = _HealthCheckStatus.error;
        _healthCheckError = 'Apps Scriptとの通信中に予期しないエラーが発生しました。';
      });
    }
  }

  @override
  void dispose() {
    _authService.removeListener(_handleAuthChanged);
    if (_ownsAppsScriptApiService) {
      _appsScriptApiService.close();
    }
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
                            'Apps Script通信確認',
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Googleログインに加え、ブラウザからApps Scriptの'
                            'healthCheckを呼び出せることを確認します。'
                            'この段階ではIDトークンの検証やDrive接続はまだ行いません。',
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
                            completed: _authService.status ==
                                GoogleAuthStatus.signedIn,
                          ),
                          const Divider(height: 32),
                          _StatusRow(
                            icon: Icons.key_outlined,
                            label: 'IDトークン',
                            status: _tokenStatusText,
                            completed: _authService.hasIdToken,
                          ),
                          const Divider(height: 32),
                          _StatusRow(
                            icon: Icons.cloud_outlined,
                            label: 'Apps Script healthCheck',
                            status: _healthCheckStatusText,
                            completed: _healthCheckStatus ==
                                _HealthCheckStatus.success,
                          ),
                          const SizedBox(height: 24),
                          _AuthActionPanel(authService: _authService),
                          const SizedBox(height: 24),
                          _HealthCheckPanel(
                            status: _healthCheckStatus,
                            response: _healthCheckResponse,
                            errorMessage: _healthCheckError,
                            onRun: _runHealthCheck,
                          ),
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

    return _authService.status == GoogleAuthStatus.initializing
        ? '確認中'
        : '未取得';
  }

  String get _healthCheckStatusText {
    return switch (_healthCheckStatus) {
      _HealthCheckStatus.notRun => '未実行',
      _HealthCheckStatus.running => '通信中',
      _HealthCheckStatus.success => '通信成功',
      _HealthCheckStatus.error => '通信失敗',
    };
  }
}

enum _HealthCheckStatus {
  notRun,
  running,
  success,
  error,
}

class _HealthCheckPanel extends StatelessWidget {
  const _HealthCheckPanel({
    required this.status,
    required this.response,
    required this.errorMessage,
    required this.onRun,
  });

  final _HealthCheckStatus status;
  final HealthCheckResponse? response;
  final String? errorMessage;
  final Future<void> Function() onRun;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Apps Script疎通確認',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          const Text(
            '固定のhealthCheckをPOSTし、ブラウザ通信が許可されているか確認します。',
          ),
          if (status == _HealthCheckStatus.running) ...<Widget>[
            const SizedBox(height: 16),
            const Row(
              children: <Widget>[
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Expanded(child: Text('Apps Scriptへ通信しています。')),
              ],
            ),
          ],
          if (status == _HealthCheckStatus.success && response != null)
            ...<Widget>[
              const SizedBox(height: 16),
              _ResultRow(
                icon: Icons.check_circle,
                label: '結果',
                value: '通信成功',
                color: colorScheme.primary,
              ),
              const SizedBox(height: 8),
              _ResultRow(
                icon: Icons.schedule_outlined,
                label: 'サーバー時刻',
                value: response!.serverTime ?? '未取得',
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              _ResultRow(
                icon: Icons.http_outlined,
                label: '応答',
                value:
                    '${response!.method ?? '不明'} / ${response!.stage ?? '不明'}',
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          if (status == _HealthCheckStatus.error && errorMessage != null)
            ...<Widget>[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  errorMessage!,
                  style: TextStyle(color: colorScheme.onErrorContainer),
                ),
              ),
            ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: status == _HealthCheckStatus.running ? null : onRun,
              icon: const Icon(Icons.cloud_sync_outlined),
              label: Text(
                status == _HealthCheckStatus.success
                    ? 'healthCheckを再実行'
                    : 'healthCheckを実行',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: SelectableText(value)),
      ],
    );
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

    children.add(
      switch (authService.status) {
        GoogleAuthStatus.initializing => const _InitializingPanel(),
        GoogleAuthStatus.signedOut => const _SignedOutPanel(),
        GoogleAuthStatus.signedIn => _SignedInPanel(
            authService: authService,
          ),
        GoogleAuthStatus.error => const _SignedOutPanel(),
      },
    );

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
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
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
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
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
