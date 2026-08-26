part of '../record_page.dart';

class _DraftLock extends StatelessWidget {
  const _DraftLock({required this.locked, required this.child});

  final bool locked;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: locked,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: locked ? 0.72 : 1,
        child: child,
      ),
    );
  }
}

class _ReauthenticationPanel extends StatelessWidget {
  const _ReauthenticationPanel({required this.controller});

  final RecordDraftController controller;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.lock_clock_outlined, color: colors.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Googleログインの有効期限が切れました',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: colors.onErrorContainer,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '選択した写真・建物・タグ・感想・位置はこの画面に保持されています。認証を更新すると、候補データを読み直して作業を続けられます。',
                        style: TextStyle(color: colors.onErrorContainer),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const Key('refresh-record-authentication'),
              onPressed: controller.isRefreshingAuthentication
                  ? null
                  : () {
                      unawaited(controller.refreshAuthentication());
                    },
              icon: controller.isRefreshingAuthentication
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_outlined),
              label: Text(
                controller.isRefreshingAuthentication
                    ? '認証を更新しています'
                    : '認証をもう一度更新',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '上の操作で戻らない場合は、下のGoogleボタンから同じアカウントでログインしてください。',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onErrorContainer),
            ),
            const SizedBox(height: 10),
            Center(child: buildGoogleSignInButton()),
          ],
        ),
      ),
    );
  }
}

class _ActivityStatusPanel extends StatelessWidget {
  const _ActivityStatusPanel({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.icon,
    required this.message,
    this.isError = false,
  });

  final IconData icon;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color background = isError
        ? colors.errorContainer
        : colors.primaryContainer;
    final Color foreground = isError
        ? colors.onErrorContainer
        : colors.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: foreground)),
          ),
        ],
      ),
    );
  }
}
