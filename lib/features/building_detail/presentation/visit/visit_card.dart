part of '../building_detail_page.dart';

class _VisitCard extends StatelessWidget {
  const _VisitCard({
    required this.visit,
    required this.photoCount,
    required this.tagsById,
    required this.onEdit,
    required this.onAddPhotos,
    required this.onHide,
  });

  final BuildingVisit visit;
  final int photoCount;
  final Map<String, BuildingTag> tagsById;
  final VoidCallback onEdit;
  final VoidCallback onAddPhotos;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final List<String> triggerNames = visit.triggerTags
        .map((String id) => tagsById[id]?.tagName ?? '未登録タグ')
        .toList(growable: false);

    return Container(
      key: ValueKey<String>('building-visit-${visit.visitId}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.calendar_today, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _formatDateTime(visit.visitedAt),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Chip(
                avatar: const Icon(Icons.photo, size: 17),
                label: Text('$photoCount枚'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (triggerNames.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: triggerNames
                  .map(
                    (String name) => Chip(
                      label: Text(name),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          if (visit.impression.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(visit.impression),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: <Widget>[
              if (visit.latitude != null && visit.longitude != null)
                _MetadataText(
                  icon: Icons.location_on_outlined,
                  text:
                      '${visit.latitude!.toStringAsFixed(6)}, ${visit.longitude!.toStringAsFixed(6)}',
                ),
              if (visit.accuracyM != null)
                _MetadataText(
                  icon: Icons.gps_fixed,
                  text: '精度 ${visit.accuracyM!.toStringAsFixed(1)}m',
                ),
              if (visit.locationSource.isNotEmpty)
                _MetadataText(
                  icon: Icons.my_location,
                  text: _locationSourceLabel(visit.locationSource),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                key: ValueKey<String>('edit-visit-${visit.visitId}'),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_calendar_outlined),
                label: const Text('訪問記録を編集'),
              ),
              OutlinedButton.icon(
                key: ValueKey<String>('add-photos-to-visit-${visit.visitId}'),
                onPressed: onAddPhotos,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('写真を追加'),
              ),
              TextButton.icon(
                key: ValueKey<String>('hide-visit-${visit.visitId}'),
                onPressed: onHide,
                icon: const Icon(Icons.visibility_off_outlined),
                label: const Text('非表示'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
