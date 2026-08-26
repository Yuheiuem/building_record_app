part of '../building_detail_page.dart';

class _HiddenPhotoManagerDialog extends StatefulWidget {
  const _HiddenPhotoManagerDialog({
    required this.apiService,
    required this.buildingId,
    required this.idToken,
  });

  final PhotoLifecycleApiService apiService;
  final String buildingId;
  final String idToken;

  @override
  State<_HiddenPhotoManagerDialog> createState() =>
      _HiddenPhotoManagerDialogState();
}

class _HiddenPhotoManagerDialogState extends State<_HiddenPhotoManagerDialog> {
  final List<BuildingPhoto> _photos = <BuildingPhoto>[];
  bool _isLoading = false;
  bool _isMutating = false;
  bool _changed = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_load());
    });
  }

  Future<void> _load() async {
    if (_isLoading) {
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<BuildingPhoto> photos = await widget.apiService
          .getHiddenBuildingPhotos(
            requestId: const Uuid().v4(),
            clientVersion: AppConfig.version,
            idToken: widget.idToken,
            buildingId: widget.buildingId,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _photos
          ..clear()
          ..addAll(photos);
        _isLoading = false;
      });
    } on PhotoLifecycleApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = '非表示写真を取得できませんでした。もう一度お試しください。';
      });
    }
  }

  Future<void> _preview(BuildingPhoto photo) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _HiddenPhotoPreviewDialog(
          apiService: widget.apiService,
          idToken: widget.idToken,
          photo: photo,
        );
      },
    );
  }

  Future<void> _restore(BuildingPhoto photo) async {
    if (_isMutating) {
      return;
    }
    setState(() {
      _isMutating = true;
      _errorMessage = null;
    });

    try {
      await widget.apiService.restorePhoto(
        requestId: const Uuid().v4(),
        clientVersion: AppConfig.version,
        idToken: widget.idToken,
        buildingId: widget.buildingId,
        photoId: photo.photoId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _photos.removeWhere(
          (BuildingPhoto item) => item.photoId == photo.photoId,
        );
        _isMutating = false;
        _changed = true;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('写真を復元しました。')));
    } on PhotoLifecycleApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isMutating = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isMutating = false;
        _errorMessage = '写真を復元できませんでした。もう一度お試しください。';
      });
    }
  }

  Future<void> _deletePermanently(BuildingPhoto photo) async {
    if (_isMutating) {
      return;
    }
    final bool confirmed = await _confirmPermanentPhotoDeletion(context, photo);
    if (!mounted || !confirmed) {
      return;
    }

    setState(() {
      _isMutating = true;
      _errorMessage = null;
    });
    try {
      await widget.apiService.deletePhotoPermanently(
        requestId: const Uuid().v4(),
        clientVersion: AppConfig.version,
        idToken: widget.idToken,
        buildingId: widget.buildingId,
        photoId: photo.photoId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _photos.removeWhere(
          (BuildingPhoto item) => item.photoId == photo.photoId,
        );
        _isMutating = false;
        _changed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('写真をGoogle Driveから完全に削除しました。')),
      );
    } on PhotoLifecycleApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isMutating = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isMutating = false;
        _errorMessage = '写真を完全削除できませんでした。もう一度お試しください。';
      });
    }
  }

  void _close() {
    Navigator.of(context).pop(_changed);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('非表示写真を管理'),
          leading: IconButton(
            key: const Key('close-hidden-photo-manager'),
            onPressed: _isMutating ? null : _close,
            tooltip: '閉じる',
            icon: const Icon(Icons.close),
          ),
          actions: <Widget>[
            IconButton(
              key: const Key('refresh-hidden-photos'),
              onPressed: _isLoading || _isMutating ? null : _load,
              tooltip: '再取得',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: <Widget>[
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: <Widget>[
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Icon(Icons.info_outline),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '非表示写真はDrive上に残っているため復元できます。'
                              '「完全に削除」を選ぶと元画像とサムネイルを削除し、復元できなくなります。',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_errorMessage != null) ...<Widget>[
                    const SizedBox(height: 12),
                    _InlineErrorMessage(message: _errorMessage!),
                  ],
                  const SizedBox(height: 12),
                  if (_isLoading && _photos.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_photos.isEmpty)
                    const _SectionEmptyState(
                      icon: Icons.visibility_outlined,
                      message: '非表示の写真はありません。',
                    )
                  else
                    ..._photos.map((BuildingPhoto photo) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          key: ValueKey<String>(
                            'hidden-photo-${photo.photoId}',
                          ),
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                Text(
                                  photo.fileName,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  children: <Widget>[
                                    Text(
                                      _formatDateTime(
                                        photo.takenAt ?? photo.createdAt,
                                      ),
                                    ),
                                    Text(_formatBytes(photo.byteSize)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  alignment: WrapAlignment.end,
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: <Widget>[
                                    OutlinedButton.icon(
                                      key: ValueKey<String>(
                                        'preview-hidden-photo-${photo.photoId}',
                                      ),
                                      onPressed: _isMutating
                                          ? null
                                          : () => _preview(photo),
                                      icon: const Icon(Icons.image_outlined),
                                      label: const Text('確認'),
                                    ),
                                    FilledButton.tonalIcon(
                                      key: ValueKey<String>(
                                        'restore-hidden-photo-${photo.photoId}',
                                      ),
                                      onPressed: _isMutating
                                          ? null
                                          : () => _restore(photo),
                                      icon: const Icon(Icons.restore),
                                      label: const Text('復元'),
                                    ),
                                    TextButton.icon(
                                      key: ValueKey<String>(
                                        'delete-hidden-photo-${photo.photoId}',
                                      ),
                                      onPressed: _isMutating
                                          ? null
                                          : () => _deletePermanently(photo),
                                      icon: Icon(
                                        Icons.delete_forever_outlined,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                      label: Text(
                                        '完全に削除',
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
              if (_isMutating)
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
