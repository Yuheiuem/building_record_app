part of '../building_detail_page.dart';

class _VisitHistorySection extends StatelessWidget {
  const _VisitHistorySection({
    required this.detail,
    required this.tagsById,
    required this.onEditVisit,
    required this.onAddPhotos,
    required this.onHideVisit,
    required this.onManageHiddenVisits,
  });

  final BuildingDetailData detail;
  final Map<String, BuildingTag> tagsById;
  final ValueChanged<BuildingVisit> onEditVisit;
  final ValueChanged<BuildingVisit> onAddPhotos;
  final ValueChanged<BuildingVisit> onHideVisit;
  final VoidCallback onManageHiddenVisits;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.history,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '訪問履歴',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text('${detail.visits.length}件'),
              ],
            ),
            const SizedBox(height: 12),
            if (detail.visits.isEmpty)
              const _SectionEmptyState(
                icon: Icons.event_busy,
                message: '完了した訪問記録はまだありません。',
              )
            else
              ListView.separated(
                key: const Key('building-visit-history'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: detail.visits.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(height: 10),
                itemBuilder: (BuildContext context, int index) {
                  final BuildingVisit visit = detail.visits[index];
                  return _VisitCard(
                    visit: visit,
                    photoCount: detail.photosForVisit(visit.visitId).length,
                    tagsById: tagsById,
                    onEdit: () => onEditVisit(visit),
                    onAddPhotos: () => onAddPhotos(visit),
                    onHide: () => onHideVisit(visit),
                  );
                },
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('manage-hidden-visits'),
              onPressed: onManageHiddenVisits,
              icon: const Icon(Icons.visibility_off_outlined),
              label: const Text('非表示の訪問を管理'),
            ),
          ],
        ),
      ),
    );
  }
}
