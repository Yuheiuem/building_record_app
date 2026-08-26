part of '../building_detail_page.dart';

class _HiddenPhotoPreviewDialog extends StatefulWidget {
  const _HiddenPhotoPreviewDialog({
    required this.apiService,
    required this.idToken,
    required this.photo,
  });

  final PhotoLifecycleApiService apiService;
  final String idToken;
  final BuildingPhoto photo;

  @override
  State<_HiddenPhotoPreviewDialog> createState() =>
      _HiddenPhotoPreviewDialogState();
}

class _HiddenPhotoPreviewDialogState extends State<_HiddenPhotoPreviewDialog> {
  late Future<BuildingPhotoData> _photoFuture;

  @override
  void initState() {
    super.initState();
    _photoFuture = _load();
  }

  Future<BuildingPhotoData> _load() {
    return widget.apiService.getHiddenPhotoThumbnailData(
      requestId: const Uuid().v4(),
      clientVersion: AppConfig.version,
      idToken: widget.idToken,
      photoId: widget.photo.photoId,
    );
  }

  void _retry() {
    setState(() {
      _photoFuture = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('非表示写真を確認'),
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            tooltip: '閉じる',
            icon: const Icon(Icons.close),
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
                          const Text('非表示写真を取得できませんでした。'),
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
                          Text(widget.photo.fileName),
                          Text(
                            _formatDateTime(
                              widget.photo.takenAt ?? widget.photo.createdAt,
                            ),
                          ),
                          Text(_formatBytes(widget.photo.byteSize)),
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
