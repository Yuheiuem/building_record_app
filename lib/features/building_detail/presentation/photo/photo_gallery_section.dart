part of '../building_detail_page.dart';

class _PhotoGallerySection extends StatelessWidget {
  const _PhotoGallerySection({
    required this.allPhotoCount,
    required this.photos,
    required this.coverPhotoId,
    required this.thumbnailFuture,
    required this.onRetryThumbnail,
    required this.onOpenPhoto,
    required this.onSetCoverPhoto,
    required this.onHidePhoto,
    required this.onDeletePhotoPermanently,
    required this.onManageHiddenPhotos,
    required this.onShowMore,
    required this.onOpenDrive,
  });

  final int allPhotoCount;
  final List<BuildingPhoto> photos;
  final String? coverPhotoId;
  final Future<BuildingPhotoData> Function(BuildingPhoto photo) thumbnailFuture;
  final ValueChanged<BuildingPhoto> onRetryThumbnail;
  final ValueChanged<BuildingPhoto> onOpenPhoto;
  final ValueChanged<BuildingPhoto> onSetCoverPhoto;
  final ValueChanged<BuildingPhoto> onHidePhoto;
  final ValueChanged<BuildingPhoto> onDeletePhotoPermanently;
  final VoidCallback onManageHiddenPhotos;
  final VoidCallback? onShowMore;
  final VoidCallback? onOpenDrive;

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
                  Icons.photo_library,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '写真ギャラリー',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text('$allPhotoCount枚'),
              ],
            ),
            const SizedBox(height: 12),
            if (photos.isEmpty)
              const _SectionEmptyState(
                icon: Icons.photo,
                message: 'この建物の写真はまだありません。',
              )
            else
              GridView.builder(
                key: const Key('building-photo-gallery'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 300,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.18,
                ),
                itemCount: photos.length,
                itemBuilder: (BuildContext context, int index) {
                  final BuildingPhoto photo = photos[index];
                  return _AuthenticatedPhotoTile(
                    key: ValueKey<String>('building-photo-${photo.photoId}'),
                    photo: photo,
                    thumbnailFuture: thumbnailFuture(photo),
                    isCoverPhoto: coverPhotoId == photo.photoId,
                    onRetry: () => onRetryThumbnail(photo),
                    onOpen: () => onOpenPhoto(photo),
                    onSetCoverPhoto: () => onSetCoverPhoto(photo),
                    onHidePhoto: () => onHidePhoto(photo),
                    onDeletePermanently: () => onDeletePhotoPermanently(photo),
                  );
                },
              ),
            if (onShowMore != null) ...<Widget>[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('show-all-building-photos'),
                onPressed: onShowMore,
                icon: const Icon(Icons.expand_more),
                label: Text('すべて表示（残り${allPhotoCount - photos.length}枚）'),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('manage-hidden-building-photos'),
              onPressed: onManageHiddenPhotos,
              icon: const Icon(Icons.visibility_off_outlined),
              label: const Text('非表示写真を管理'),
            ),
            if (onOpenDrive != null) ...<Widget>[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('open-building-drive-folder'),
                onPressed: onOpenDrive,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Google Driveで写真フォルダを開く'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
