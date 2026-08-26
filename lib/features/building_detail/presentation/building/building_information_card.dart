part of '../building_detail_page.dart';

class _BuildingInformationCard extends StatelessWidget {
  const _BuildingInformationCard({
    required this.detail,
    required this.tagsById,
    required this.onRefresh,
    required this.onEditInformation,
    required this.onEditLocation,
    required this.onHideBuilding,
    required this.onDeleteBuildingPermanently,
    required this.onRecordRevisit,
  });

  final BuildingDetailData detail;
  final Map<String, BuildingTag> tagsById;
  final Future<void> Function() onRefresh;
  final VoidCallback onEditInformation;
  final VoidCallback onEditLocation;
  final VoidCallback onHideBuilding;
  final VoidCallback onDeleteBuildingPermanently;
  final VoidCallback onRecordRevisit;

  @override
  Widget build(BuildContext context) {
    final Building building = detail.building;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.apartment_outlined,
                  size: 34,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        building.buildingName,
                        key: const Key('building-detail-name'),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (building.address != null) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          building.address!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('refresh-building-detail'),
                  tooltip: '最新データを取得',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _CountChip(
                  icon: Icons.event_note,
                  label: '訪問 ${detail.counts.visits}件',
                ),
                _CountChip(
                  icon: Icons.photo_library,
                  label: '写真 ${detail.counts.photos}枚',
                ),
                if (building.latitude != null && building.longitude != null)
                  _CountChip(
                    key: const Key('building-representative-location-chip'),
                    icon: Icons.location_on_outlined,
                    label: '代表位置あり',
                    onPressed: onEditLocation,
                  ),
              ],
            ),
            const SizedBox(height: 18),
            _TagGroup(
              title: '設計',
              tagIds: building.designTags,
              tagsById: tagsById,
            ),
            const SizedBox(height: 10),
            _TagGroup(
              title: '営業',
              tagIds: building.salesTags,
              tagsById: tagsById,
            ),
            const SizedBox(height: 10),
            _TagGroup(
              title: '施工',
              tagIds: building.constructionTags,
              tagsById: tagsById,
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              key: const Key('edit-building-information'),
              onPressed: onEditInformation,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('建物情報を編集'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              key: const Key('record-building-revisit'),
              onPressed: onRecordRevisit,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('再訪を記録'),
            ),
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'その他の操作',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('hide-building'),
              onPressed: onHideBuilding,
              icon: const Icon(Icons.visibility_off_outlined),
              label: const Text('建物を非表示にする'),
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              key: const Key('delete-building-permanently'),
              onPressed: onDeleteBuildingPermanently,
              icon: const Icon(Icons.delete_forever),
              label: const Text('建物を完全に削除'),
              style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.icon,
    required this.label,
    this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final Widget avatar = Icon(icon, size: 18);
    if (onPressed != null) {
      return ActionChip(
        avatar: avatar,
        label: Text(label),
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
      );
    }
    return Chip(
      avatar: avatar,
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _TagGroup extends StatelessWidget {
  const _TagGroup({
    required this.title,
    required this.tagIds,
    required this.tagsById,
  });

  final String title;
  final List<String> tagIds;
  final Map<String, BuildingTag> tagsById;

  @override
  Widget build(BuildContext context) {
    final List<String> names = tagIds
        .map((String id) => tagsById[id]?.tagName ?? '未登録タグ')
        .toList(growable: false);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 54,
          child: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        Expanded(
          child: names.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(
                    '未登録',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: names
                      .map(
                        (String name) => Chip(
                          label: Text(name),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(growable: false),
                ),
        ),
      ],
    );
  }
}
