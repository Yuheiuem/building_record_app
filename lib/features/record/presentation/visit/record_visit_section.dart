part of '../record_page.dart';

class _VisitDraftSection extends StatelessWidget {
  const _VisitDraftSection({
    required this.controller,
    required this.onAddTag,
    required this.onPickMapLocation,
  });

  final RecordDraftController controller;
  final ValueChanged<BuildingTagType> onAddTag;
  final VoidCallback onPickMapLocation;

  @override
  Widget build(BuildContext context) {
    final List<BuildingTag> triggerTags = controller.tagsFor(
      BuildingTagType.trigger,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.edit_note_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '今回の訪問',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('訪問のきっかけ、感想、撮影した場所を下書きへ追加します。'),
            const SizedBox(height: 20),
            _TagSelectorAccordion(
              type: BuildingTagType.trigger,
              tags: triggerTags,
              controller: controller,
              chipKeyPrefix: 'visit-trigger-tag',
              onToggleTag: controller.toggleTriggerTag,
              onAddTag: () => onAddTag(BuildingTagType.trigger),
            ),
            const SizedBox(height: 20),
            TextFormField(
              key: const Key('visit-impression-field'),
              initialValue: controller.impression,
              onChanged: controller.setImpression,
              minLines: 4,
              maxLines: 8,
              maxLength: 2000,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: '感想',
                hintText: '空間の印象、気づいた点、あとで調べたいことなど',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            _VisitLocationPanel(
              controller: controller,
              onPickMapLocation: onPickMapLocation,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.info_outline, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '複数写真はまとめて送信します。途中で失敗した場合は、入力内容と送信済み写真を保持して失敗分だけ再送します。',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisitLocationPanel extends StatelessWidget {
  const _VisitLocationPanel({
    required this.controller,
    required this.onPickMapLocation,
  });

  final RecordDraftController controller;
  final VoidCallback onPickMapLocation;

  @override
  Widget build(BuildContext context) {
    final RecordDraftLocation? location = controller.visitLocation;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Container(
      key: const Key('visit-location-panel'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.my_location_outlined, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                '位置情報',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (controller.isGettingLocation) ...<Widget>[
            const LinearProgressIndicator(),
            const SizedBox(height: 10),
            const Text('現在地を取得しています。'),
          ] else if (location == null)
            const _LocationEmptyState()
          else
            _LocationValue(location: location),
          if (controller.locationErrorMessage != null) ...<Widget>[
            const SizedBox(height: 12),
            _InlineLocationMessage(
              message: controller.locationErrorMessage!,
              isError: true,
            ),
          ],
          if (controller.locationNoticeMessage != null) ...<Widget>[
            const SizedBox(height: 12),
            _InlineLocationMessage(message: controller.locationNoticeMessage!),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                key: const Key('capture-current-location'),
                onPressed: controller.isGettingLocation
                    ? null
                    : controller.acquireCurrentLocation,
                icon: const Icon(Icons.gps_fixed_outlined),
                label: Text(location == null ? '現在地を取得' : '現在地を再取得'),
              ),
              OutlinedButton.icon(
                key: const Key('pick-location-on-map'),
                onPressed: controller.isGettingLocation
                    ? null
                    : onPickMapLocation,
                icon: const Icon(Icons.map_outlined),
                label: const Text('地図で位置を指定'),
              ),
              if (controller.canUseSelectedBuildingLocation)
                OutlinedButton.icon(
                  key: const Key('use-building-location'),
                  onPressed: controller.isGettingLocation
                      ? null
                      : controller.useSelectedBuildingLocation,
                  icon: const Icon(Icons.apartment_outlined),
                  label: const Text('建物の代表位置を使う'),
                ),
              if (location != null)
                TextButton.icon(
                  key: const Key('clear-visit-location'),
                  onPressed: controller.isGettingLocation
                      ? null
                      : controller.clearVisitLocation,
                  icon: const Icon(Icons.clear_outlined),
                  label: const Text('位置をクリア'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LocationEmptyState extends StatelessWidget {
  const _LocationEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: <Widget>[
          Icon(Icons.location_off_outlined),
          SizedBox(width: 8),
          Expanded(child: Text('位置はまだ取得されていません。')),
        ],
      ),
    );
  }
}

class _LocationValue extends StatelessWidget {
  const _LocationValue({required this.location});

  final RecordDraftLocation location;

  @override
  Widget build(BuildContext context) {
    final String accuracyText = location.accuracyM == null
        ? '未設定'
        : '±${location.accuracyM!.toStringAsFixed(1)} m';

    return Container(
      key: const Key('visit-location-value'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _LocationRow(label: '取得方法', value: location.source.displayName),
          const SizedBox(height: 6),
          _LocationRow(
            label: '緯度',
            value: location.latitude.toStringAsFixed(6),
          ),
          const SizedBox(height: 6),
          _LocationRow(
            label: '経度',
            value: location.longitude.toStringAsFixed(6),
          ),
          const SizedBox(height: 6),
          _LocationRow(label: '精度', value: accuracyText),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}

class _InlineLocationMessage extends StatelessWidget {
  const _InlineLocationMessage({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color background = isError
        ? colors.errorContainer
        : colors.secondaryContainer;
    final Color foreground = isError
        ? colors.onErrorContainer
        : colors.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: foreground,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: foreground)),
          ),
        ],
      ),
    );
  }
}
