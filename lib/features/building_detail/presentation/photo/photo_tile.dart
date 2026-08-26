part of '../building_detail_page.dart';

enum _PhotoTileAction { hide, deletePermanently }

class _AuthenticatedPhotoTile extends StatelessWidget {
  const _AuthenticatedPhotoTile({
    required this.photo,
    required this.thumbnailFuture,
    required this.isCoverPhoto,
    required this.onRetry,
    required this.onOpen,
    required this.onSetCoverPhoto,
    required this.onHidePhoto,
    required this.onDeletePermanently,
    super.key,
  });

  final BuildingPhoto photo;
  final Future<BuildingPhotoData> thumbnailFuture;
  final bool isCoverPhoto;
  final VoidCallback onRetry;
  final VoidCallback onOpen;
  final VoidCallback onSetCoverPhoto;
  final VoidCallback onHidePhoto;
  final VoidCallback onDeletePermanently;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BuildingPhotoData>(
      future: thumbnailFuture,
      builder: (BuildContext context, AsyncSnapshot<BuildingPhotoData> snapshot) {
        if (snapshot.hasData) {
          final BuildingPhotoData data = snapshot.data!;
          return Material(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: InkWell(
              onTap: onOpen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: Image.memory(
                      data.bytes,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder:
                          (
                            BuildContext context,
                            Object error,
                            StackTrace? stackTrace,
                          ) {
                            return const Center(
                              child: Icon(Icons.broken_image, size: 42),
                            );
                          },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            _formatDateTime(photo.takenAt ?? photo.createdAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        IconButton(
                          key: ValueKey<String>(
                            'set-cover-photo-${photo.photoId}',
                          ),
                          tooltip: isCoverPhoto ? '代表写真に設定済み' : '代表写真に設定',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 34,
                            height: 34,
                          ),
                          onPressed: isCoverPhoto ? null : onSetCoverPhoto,
                          icon: Icon(
                            isCoverPhoto ? Icons.star : Icons.star_border,
                            color: isCoverPhoto
                                ? Theme.of(context).colorScheme.primary
                                : null,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 2),
                        PopupMenuButton<_PhotoTileAction>(
                          key: ValueKey<String>(
                            'photo-actions-${photo.photoId}',
                          ),
                          tooltip: '写真の操作',
                          padding: EdgeInsets.zero,
                          onSelected: (_PhotoTileAction action) {
                            switch (action) {
                              case _PhotoTileAction.hide:
                                onHidePhoto();
                                return;
                              case _PhotoTileAction.deletePermanently:
                                onDeletePermanently();
                                return;
                            }
                          },
                          itemBuilder: (BuildContext context) {
                            final Color errorColor = Theme.of(
                              context,
                            ).colorScheme.error;
                            return <PopupMenuEntry<_PhotoTileAction>>[
                              PopupMenuItem<_PhotoTileAction>(
                                key: ValueKey<String>(
                                  'hide-photo-${photo.photoId}',
                                ),
                                value: _PhotoTileAction.hide,
                                child: const ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.visibility_off_outlined),
                                  title: Text('非表示にする'),
                                ),
                              ),
                              PopupMenuItem<_PhotoTileAction>(
                                key: ValueKey<String>(
                                  'delete-photo-permanently-${photo.photoId}',
                                ),
                                value: _PhotoTileAction.deletePermanently,
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    Icons.delete_forever_outlined,
                                    color: errorColor,
                                  ),
                                  title: Text(
                                    '完全に削除',
                                    style: TextStyle(color: errorColor),
                                  ),
                                ),
                              ),
                            ];
                          },
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.zoom_in, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(Icons.broken_image, size: 36),
                  const SizedBox(height: 8),
                  const Text('写真を取得できませんでした。'),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('再試行'),
                  ),
                ],
              ),
            ),
          );
        }

        return DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
