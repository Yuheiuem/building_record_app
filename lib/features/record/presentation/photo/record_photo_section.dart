part of '../record_page.dart';

class _DraftHeader extends StatelessWidget {
  const _DraftHeader({
    required this.isPicking,
    required this.hasPhotos,
    required this.statusMessage,
    required this.onAddPhotos,
    required this.onClearPhotos,
  });

  final bool isPicking;
  final bool hasPhotos;
  final String? statusMessage;
  final VoidCallback onAddPhotos;
  final VoidCallback onClearPhotos;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.photo_library_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '写真の下書き',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('建築の写真を複数選択できます。選択した写真は送信前の下書きとして、この画面内だけに保持します。'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
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
                      '「記録を保存」を押すまでは写真・建物・訪問を送信しません。新しく追加したタグだけはタグマスターへ保存されます。',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.icon(
                  key: const Key('select-record-photos'),
                  onPressed: isPicking ? null : onAddPhotos,
                  icon: isPicking
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(
                    isPicking
                        ? '写真を読み込んでいます'
                        : hasPhotos
                        ? '写真を追加する'
                        : '写真を選択する',
                  ),
                ),
                if (hasPhotos)
                  OutlinedButton.icon(
                    key: const Key('clear-record-photos'),
                    onPressed: isPicking ? null : onClearPhotos,
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: const Text('すべて削除'),
                  ),
              ],
            ),
            if (statusMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              _ActivityStatusPanel(
                key: const Key('record-photo-preparation-status'),
                message: statusMessage!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyDraftPanel extends StatelessWidget {
  const _EmptyDraftPanel();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.photo_outlined,
              size: 52,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              '写真がまだ選択されていません',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              '「写真を選択する」から、今回の訪問で記録する写真を追加してください。',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoDraftSection extends StatelessWidget {
  const _PhotoDraftSection({
    required this.photos,
    required this.totalBytes,
    required this.onRemovePhoto,
  });

  final List<RecordDraftPhoto> photos;
  final int totalBytes;
  final ValueChanged<String> onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 20,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: <Widget>[
                _SummaryValue(
                  key: const Key('record-photo-count'),
                  icon: Icons.photo_library_outlined,
                  label: '選択枚数',
                  value: '${photos.length}枚',
                ),
                _SummaryValue(
                  key: const Key('record-total-size'),
                  icon: Icons.data_usage_outlined,
                  label: '合計容量',
                  value: _formatBytes(totalBytes),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int columnCount;
            if (constraints.maxWidth >= 900) {
              columnCount = 4;
            } else if (constraints.maxWidth >= 620) {
              columnCount = 3;
            } else {
              columnCount = 2;
            }

            const double spacing = 12;
            const double childAspectRatio = 0.78;
            final int rowCount = (photos.length / columnCount).ceil();
            final double cardWidth =
                (constraints.maxWidth - spacing * (columnCount - 1)) /
                columnCount;
            final double cardHeight = cardWidth / childAspectRatio;
            final double contentHeight =
                rowCount * cardHeight + math.max(0, rowCount - 1) * spacing;
            final double maxGridHeight =
                MediaQuery.sizeOf(context).height * 0.7;
            final double gridHeight = math.min(contentHeight, maxGridHeight);

            return SizedBox(
              key: const Key('record-photo-draft-scroll'),
              height: gridHeight,
              child: GridView.builder(
                primary: false,
                physics: contentHeight > maxGridHeight
                    ? const ClampingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                itemCount: photos.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columnCount,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                  childAspectRatio: childAspectRatio,
                ),
                itemBuilder: (BuildContext context, int index) {
                  final RecordDraftPhoto photo = photos[index];
                  return _DraftPhotoCard(
                    key: ValueKey<String>('draft-photo-${photo.photoId}'),
                    photo: photo,
                    onRemove: () => onRemovePhoto(photo.photoId),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }
}

class _DraftPhotoCard extends StatelessWidget {
  const _DraftPhotoCard({
    required this.photo,
    required this.onRemove,
    super.key,
  });

  final RecordDraftPhoto photo;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: Image.memory(
              photo.bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stackTrace) {
                    return ColoredBox(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: const Center(
                        child: Icon(Icons.broken_image_outlined, size: 40),
                      ),
                    );
                  },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 4, 6),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        photo.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatBytes(photo.byteSize),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: Key('remove-draft-photo-${photo.photoId}'),
                  onPressed: onRemove,
                  tooltip: '${photo.fileName}を削除',
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
