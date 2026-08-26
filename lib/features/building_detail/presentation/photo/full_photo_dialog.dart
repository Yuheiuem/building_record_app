part of '../building_detail_page.dart';

class _FullPhotoDialog extends StatefulWidget {
  const _FullPhotoDialog({
    required this.photo,
    required this.loadPhoto,
    required this.onRetry,
  });

  final BuildingPhoto photo;
  final Future<BuildingPhotoData> Function() loadPhoto;
  final VoidCallback onRetry;

  @override
  State<_FullPhotoDialog> createState() => _FullPhotoDialogState();
}

class _FullPhotoDialogState extends State<_FullPhotoDialog> {
  late Future<BuildingPhotoData> _photoFuture;

  @override
  void initState() {
    super.initState();
    _photoFuture = widget.loadPhoto();
  }

  void _retry() {
    widget.onRetry();
    setState(() {
      _photoFuture = widget.loadPhoto();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('写真'),
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            tooltip: '閉じる',
          ),
        ),
        body: FutureBuilder<BuildingPhotoData>(
          future: _photoFuture,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<BuildingPhotoData> snapshot,
              ) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.broken_image, size: 52),
                          const SizedBox(height: 12),
                          const Text('元の写真を取得できませんでした。'),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _retry,
                            icon: const Icon(Icons.refresh),
                            label: const Text('再試行'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final BuildingPhotoData data = snapshot.data!;
                return Column(
                  children: <Widget>[
                    Expanded(
                      child: ColoredBox(
                        color: Colors.black,
                        child: Center(
                          child: InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 5,
                            child: Image.memory(
                              data.bytes,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: <Widget>[
                          Text(
                            _formatDateTime(
                              widget.photo.takenAt ?? widget.photo.createdAt,
                            ),
                          ),
                          Text(_formatBytes(widget.photo.byteSize)),
                          if (widget.photo.width != null &&
                              widget.photo.height != null)
                            Text(
                              '${widget.photo.width} × ${widget.photo.height}',
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
        ),
      ),
    );
  }
}

Future<bool> _confirmHideBuilding(
  BuildContext context,
  Building building,
) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('建物を非表示にしますか？'),
        content: Text(
          '「${building.buildingName}」を通常の地図・一覧から非表示にします。\n\n'
          '訪問記録と写真、Google Driveのファイルは残るため、'
          'ホームの「非表示建物を管理」から復元できます。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: const Key('confirm-hide-building'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('非表示にする'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

Future<bool> _confirmPermanentBuildingDeletion(
  BuildContext context,
  BuildingLifecycleSummary summary,
) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('建物を完全に削除しますか？'),
        content: Text(
          '「${summary.building.buildingName}」を完全に削除します。\n\n'
          '訪問 ${summary.visitCount}件\n'
          '写真 ${summary.photoCount}枚\n'
          '元画像容量 ${_formatBytes(summary.photoBytes)}\n\n'
          'Google Driveの元画像とサムネイルも永久削除されます。'
          'この操作は元に戻せません。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: const Key('confirm-delete-building-permanently'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('完全に削除'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

Future<bool> _confirmHideVisit(
  BuildContext context,
  BuildingVisit visit,
) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('訪問記録を非表示にしますか？'),
        content: Text(
          '${_formatDateTime(visit.visitedAt)} の訪問記録を非表示にします。\n\n'
          'この訪問に紐づく写真も通常の建物詳細から見えなくなりますが、'
          'Google Driveのファイルは残るため、あとで復元できます。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: const Key('confirm-hide-visit'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('非表示にする'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

Future<bool> _confirmPermanentVisitDeletion(
  BuildContext context,
  VisitLifecycleSummary summary,
) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('訪問記録を完全に削除しますか？'),
        content: Text(
          '${_formatDateTime(summary.visit.visitedAt)} の訪問記録を完全に削除します。\n\n'
          '写真 ${summary.photoCount}枚\n'
          '元画像容量 ${_formatBytes(summary.photoBytes)}\n\n'
          'Google Driveの元画像とサムネイルも永久削除されます。'
          'この操作は元に戻せません。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: const Key('confirm-delete-visit-permanently'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('完全に削除'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

Future<bool> _confirmHidePhoto(
  BuildContext context,
  BuildingPhoto photo,
) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('写真を非表示にしますか？'),
        content: Text(
          '${photo.fileName}\n\n'
          '通常の写真ギャラリーから隠します。Google Drive上の元画像とサムネイルは残るため、あとで復元できます。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: const Key('confirm-hide-photo'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('非表示にする'),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

Future<bool> _confirmPermanentPhotoDeletion(
  BuildContext context,
  BuildingPhoto photo,
) async {
  final ColorScheme colorScheme = Theme.of(context).colorScheme;
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text(
          '写真を完全に削除しますか？',
          style: TextStyle(color: colorScheme.error),
        ),
        content: Text(
          '${photo.fileName}\n\n'
          'Google Drive上の元画像とサムネイルを完全に削除します。容量は解放されますが、この操作はアプリから元に戻せません。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: const Key('confirm-permanent-photo-deletion'),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('完全に削除'),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
