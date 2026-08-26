part of '../record_page.dart';

class _BuildingDraftSection extends StatelessWidget {
  const _BuildingDraftSection({
    required this.controller,
    required this.onAddTag,
  });

  final RecordDraftController controller;
  final ValueChanged<BuildingTagType> onAddTag;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.apartment_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '建物の指定',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('新しい建物を登録するか、登録済みの建物へ今回の訪問を追加するかを選びます。'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: <Widget>[
                ChoiceChip(
                  key: const Key('record-building-mode-new'),
                  selected:
                      controller.buildingMode == RecordBuildingMode.newBuilding,
                  onSelected: (bool selected) {
                    if (selected) {
                      controller.setBuildingMode(
                        RecordBuildingMode.newBuilding,
                      );
                    }
                  },
                  avatar: const Icon(Icons.add_business_outlined, size: 18),
                  label: const Text('新しい建物'),
                ),
                ChoiceChip(
                  key: const Key('record-building-mode-existing'),
                  selected:
                      controller.buildingMode ==
                      RecordBuildingMode.existingBuilding,
                  onSelected: (bool selected) {
                    if (selected) {
                      controller.setBuildingMode(
                        RecordBuildingMode.existingBuilding,
                      );
                    }
                  },
                  avatar: const Icon(Icons.search_outlined, size: 18),
                  label: const Text('登録済みの建物'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (controller.requiresReauthentication)
              const _BootstrapAuthenticationPausedPanel()
            else if (controller.isLoadingBootstrap)
              const _BootstrapLoadingPanel()
            else if (controller.bootstrapErrorMessage != null)
              _BootstrapErrorPanel(
                message: controller.bootstrapErrorMessage!,
                onRetry: () {
                  unawaited(controller.loadBootstrapData());
                },
              )
            else if (controller.hasLoadedBootstrap)
              controller.buildingMode == RecordBuildingMode.newBuilding
                  ? _NewBuildingDraftForm(
                      controller: controller,
                      onAddTag: onAddTag,
                    )
                  : _ExistingBuildingDraftForm(
                      controller: controller,
                      onAddTag: onAddTag,
                    )
            else
              const _BootstrapLoadingPanel(),
          ],
        ),
      ),
    );
  }
}

class _BootstrapAuthenticationPausedPanel extends StatelessWidget {
  const _BootstrapAuthenticationPausedPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: <Widget>[
          Icon(Icons.hourglass_top_outlined),
          SizedBox(width: 8),
          Expanded(child: Text('認証の更新後に、建物とタグの候補を自動で読み直します。')),
        ],
      ),
    );
  }
}

class _BootstrapLoadingPanel extends StatelessWidget {
  const _BootstrapLoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LinearProgressIndicator(),
        SizedBox(height: 10),
        Text('建物とタグの候補を読み込んでいます。'),
      ],
    );
  }
}

class _BootstrapErrorPanel extends StatelessWidget {
  const _BootstrapErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(message, style: TextStyle(color: colors.onErrorContainer)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('retry-record-bootstrap'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_outlined),
            label: const Text('もう一度読み込む'),
          ),
        ],
      ),
    );
  }
}
