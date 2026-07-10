import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';

class AuthSpikePage extends StatelessWidget {
  const AuthSpikePage({super.key});

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
                            '技術スパイクの準備',
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Flutter Webの最小構成が起動しています。'
                            '認証やGoogle側への接続は、次の動作確認単位で追加します。',
                            style: textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 24),
                          const _StatusRow(
                            icon: Icons.web_asset_outlined,
                            label: 'Flutter Webの土台',
                            status: '準備完了',
                            completed: true,
                          ),
                          const Divider(height: 32),
                          const _StatusRow(
                            icon: Icons.account_circle_outlined,
                            label: '専用Googleアカウント',
                            status: '作成済み',
                            completed: true,
                          ),
                          const Divider(height: 32),
                          const _StatusRow(
                            icon: Icons.lock_outline,
                            label: 'Googleログイン・Apps Script・Drive',
                            status: '次の段階',
                            completed: false,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: null,
                              icon: const Icon(Icons.login),
                              label: const Text('Googleログイン（次の段階で実装）'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '現在は実データを保存・取得しません。',
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
