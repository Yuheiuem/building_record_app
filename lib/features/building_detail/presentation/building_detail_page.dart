import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/routing/app_routes.dart';
import '../../../data/models/building.dart';
import '../../../data/models/building_detail_data.dart';
import '../../../data/models/building_tag.dart';
import '../../../data/models/record_draft_location.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/building_detail_api_service.dart';
import '../../../data/services/building_location_api_service.dart';
import '../../../shared/widgets/authenticated_app_bar.dart';
import '../../record/presentation/map_location_picker_page.dart';

class BuildingDetailPage extends StatefulWidget {
  const BuildingDetailPage({
    required this.authService,
    required this.buildingId,
    this.buildingDetailApiService,
    this.buildingLocationApiService,
    this.enableNetworkTiles = true,
    super.key,
  });

  final AuthService authService;
  final String buildingId;
  final BuildingDetailApiService? buildingDetailApiService;
  final BuildingLocationApiService? buildingLocationApiService;
  final bool enableNetworkTiles;

  @override
  State<BuildingDetailPage> createState() => _BuildingDetailPageState();
}

class _BuildingDetailPageState extends State<BuildingDetailPage> {
  static const int _initialPhotoLimit = 12;

  late final BuildingDetailApiService _apiService;
  late final bool _ownsApiService;
  late final BuildingLocationApiService _locationApiService;
  late final bool _ownsLocationApiService;

  final Map<String, Future<BuildingPhotoData>> _photoFutures =
      <String, Future<BuildingPhotoData>>{};

  BuildingDetailData? _detail;
  String? _errorMessage;
  bool _isLoading = false;
  int _visiblePhotoLimit = _initialPhotoLimit;

  @override
  void initState() {
    super.initState();
    _ownsApiService = widget.buildingDetailApiService == null;
    _apiService =
        widget.buildingDetailApiService ?? HttpBuildingDetailApiService();
    _ownsLocationApiService = widget.buildingLocationApiService == null;
    _locationApiService =
        widget.buildingLocationApiService ??
        HttpBuildingLocationApiService();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDetail();
    });
  }

  @override
  void didUpdateWidget(BuildingDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.buildingId != widget.buildingId) {
      _photoFutures.clear();
      _visiblePhotoLimit = _initialPhotoLimit;
      _detail = null;
      _errorMessage = null;
      _isLoading = false;
      unawaited(_loadDetail());
    }
  }

  @override
  void dispose() {
    if (_ownsApiService) {
      _apiService.close();
    }
    if (_ownsLocationApiService) {
      _locationApiService.close();
    }
    super.dispose();
  }

  Future<void> _loadDetail() async {
    if (_isLoading) {
      return;
    }

    final String? idToken = widget.authService.idToken;
    if (idToken == null || idToken.isEmpty) {
      setState(() {
        _errorMessage = 'Googleログイン情報を取得できませんでした。もう一度ログインしてください。';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final BuildingDetailData result = await _apiService.getBuildingDetail(
        requestId: const Uuid().v4(),
        clientVersion: AppConfig.version,
        idToken: idToken,
        buildingId: widget.buildingId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _detail = result;
        _photoFutures.clear();
        _visiblePhotoLimit = _initialPhotoLimit;
        _isLoading = false;
      });
    } on BuildingDetailApiException catch (error) {
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
        _errorMessage = '建物詳細を取得できませんでした。もう一度送信してください。';
      });
    }
  }

  Future<BuildingPhotoData> _photoFuture(BuildingPhoto photo) {
    return _photoFutures.putIfAbsent(photo.photoId, () {
      final String? idToken = widget.authService.idToken;
      if (idToken == null || idToken.isEmpty) {
        return Future<BuildingPhotoData>.error(
          const BuildingDetailApiException('Googleログイン情報を取得できませんでした。'),
        );
      }

      return _apiService.getPhotoData(
        requestId: const Uuid().v4(),
        clientVersion: AppConfig.version,
        idToken: idToken,
        photoId: photo.photoId,
      );
    });
  }

  void _retryPhoto(BuildingPhoto photo) {
    setState(() {
      _photoFutures.remove(photo.photoId);
    });
  }

  Future<void> _editBuildingLocation() async {
    final BuildingDetailData? detail = _detail;
    if (detail == null || _isLoading) {
      return;
    }

    final Building building = detail.building;
    final RecordDraftLocation? selectedLocation = await Navigator.of(context)
        .push<RecordDraftLocation>(
          MaterialPageRoute<RecordDraftLocation>(
            builder: (BuildContext context) {
              return MapLocationPickerPage(
                initialLatitude: building.latitude,
                initialLongitude: building.longitude,
                enableNetworkTiles: widget.enableNetworkTiles,
              );
            },
          ),
        );

    if (!mounted || selectedLocation == null) {
      return;
    }

    final String? idToken = widget.authService.idToken;
    if (idToken == null || idToken.isEmpty) {
      setState(() {
        _errorMessage = 'Googleログイン情報を取得できませんでした。もう一度ログインしてください。';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _locationApiService.updateBuildingLocation(
        requestId: const Uuid().v4(),
        clientVersion: AppConfig.version,
        idToken: idToken,
        buildingId: building.buildingId,
        latitude: selectedLocation.latitude,
        longitude: selectedLocation.longitude,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
      await _loadDetail();

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('建物の代表位置を更新しました。')),
      );
    } on BuildingLocationApiException catch (error) {
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
        _errorMessage = '代表位置を更新できませんでした。もう一度送信してください。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AuthenticatedAppBar(
        authService: widget.authService,
        title: '建物詳細',
        showVersion: true,
      ),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    final BuildingDetailData? detail = _detail;

    if (detail == null && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (detail == null) {
      return _DetailErrorState(
        message: _errorMessage ?? '建物詳細を取得できませんでした。',
        onRetry: _loadDetail,
      );
    }

    final Map<String, BuildingTag> tagsById = <String, BuildingTag>{
      for (final BuildingTag tag in detail.tags) tag.tagId: tag,
    };
    final int shownPhotoCount = detail.photos.length < _visiblePhotoLimit
        ? detail.photos.length
        : _visiblePhotoLimit;
    final List<BuildingPhoto> shownPhotos = detail.photos
        .take(shownPhotoCount)
        .toList(growable: false);

    return Stack(
      children: <Widget>[
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _BuildingOverviewSection(
                    detail: detail,
                    tagsById: tagsById,
                    enableNetworkTiles: widget.enableNetworkTiles,
                    onRefresh: _loadDetail,
                    onEditLocation: _editBuildingLocation,
                    onRecordRevisit: () {
                      unawaited(
                        context.push<void>(
                          AppRoutes.recordForBuilding(
                            detail.building.buildingId,
                          ),
                        ),
                      );
                    },
                  ),
                  if (_errorMessage != null) ...<Widget>[
                    const SizedBox(height: 12),
                    _InlineErrorMessage(message: _errorMessage!),
                  ],
                  const SizedBox(height: 12),
                  _PhotoGallerySection(
                    allPhotoCount: detail.photos.length,
                    photos: shownPhotos,
                    photoFuture: _photoFuture,
                    onRetryPhoto: _retryPhoto,
                    onShowMore: shownPhotoCount < detail.photos.length
                        ? () {
                            setState(() {
                              _visiblePhotoLimit += _initialPhotoLimit;
                            });
                          }
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _VisitHistorySection(
                    detail: detail,
                    tagsById: tagsById,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
        if (_isLoading)
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}

class _BuildingOverviewSection extends StatelessWidget {
  const _BuildingOverviewSection({
    required this.detail,
    required this.tagsById,
    required this.enableNetworkTiles,
    required this.onRefresh,
    required this.onEditLocation,
    required this.onRecordRevisit,
  });

  final BuildingDetailData detail;
  final Map<String, BuildingTag> tagsById;
  final bool enableNetworkTiles;
  final Future<void> Function() onRefresh;
  final VoidCallback onEditLocation;
  final VoidCallback onRecordRevisit;

  @override
  Widget build(BuildContext context) {
    final Building building = detail.building;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wideLayout = constraints.maxWidth >= 900;
        final Widget information = _BuildingInformationCard(
          detail: detail,
          tagsById: tagsById,
          onRefresh: onRefresh,
          onEditLocation: onEditLocation,
          onRecordRevisit: onRecordRevisit,
        );
        final Widget map = _BuildingLocationCard(
          building: building,
          enableNetworkTiles: enableNetworkTiles,
        );

        if (wideLayout) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(flex: 3, child: information),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(height: 420, child: map),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            information,
            const SizedBox(height: 12),
            SizedBox(height: 320, child: map),
          ],
        );
      },
    );
  }
}

class _BuildingInformationCard extends StatelessWidget {
  const _BuildingInformationCard({
    required this.detail,
    required this.tagsById,
    required this.onRefresh,
    required this.onEditLocation,
    required this.onRecordRevisit,
  });

  final BuildingDetailData detail;
  final Map<String, BuildingTag> tagsById;
  final Future<void> Function() onRefresh;
  final VoidCallback onEditLocation;
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
            FilledButton.icon(
              key: const Key('record-building-revisit'),
              onPressed: onRecordRevisit,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('再訪を記録'),
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
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
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

class _BuildingLocationCard extends StatelessWidget {
  const _BuildingLocationCard({
    required this.building,
    required this.enableNetworkTiles,
  });

  final Building building;
  final bool enableNetworkTiles;

  @override
  Widget build(BuildContext context) {
    final double? latitude = building.latitude;
    final double? longitude = building.longitude;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: <Widget>[
                const Icon(Icons.map_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '代表位置',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: latitude == null || longitude == null
                ? const Center(child: Text('代表位置は登録されていません。'))
                : FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(latitude, longitude),
                      initialZoom: 17,
                      minZoom: 5,
                      maxZoom: 19,
                    ),
                    children: <Widget>[
                      if (enableNetworkTiles)
                        TileLayer(
                          urlTemplate:
                              'https://cyberjapandata.gsi.go.jp/xyz/pale/{z}/{x}/{y}.png',
                          maxNativeZoom: 18,
                          userAgentPackageName: 'building_record_app',
                        ),
                      MarkerLayer(
                        markers: <Marker>[
                          Marker(
                            point: LatLng(latitude, longitude),
                            width: 46,
                            height: 46,
                            alignment: Alignment.bottomCenter,
                            child: Icon(
                              Icons.location_on,
                              size: 42,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SimpleAttributionWidget(
                        source: Text('国土地理院'),
                      ),
                    ],
                  ),
          ),
          if (latitude != null && longitude != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Text(
                '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _PhotoGallerySection extends StatelessWidget {
  const _PhotoGallerySection({
    required this.allPhotoCount,
    required this.photos,
    required this.photoFuture,
    required this.onRetryPhoto,
    required this.onShowMore,
  });

  final int allPhotoCount;
  final List<BuildingPhoto> photos;
  final Future<BuildingPhotoData> Function(BuildingPhoto photo) photoFuture;
  final ValueChanged<BuildingPhoto> onRetryPhoto;
  final VoidCallback? onShowMore;

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
                    future: photoFuture(photo),
                    onRetry: () => onRetryPhoto(photo),
                  );
                },
              ),
            if (onShowMore != null) ...<Widget>[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onShowMore,
                icon: const Icon(Icons.expand_more),
                label: Text('さらに表示（残り${allPhotoCount - photos.length}枚）'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AuthenticatedPhotoTile extends StatelessWidget {
  const _AuthenticatedPhotoTile({
    required this.photo,
    required this.future,
    required this.onRetry,
    super.key,
  });

  final BuildingPhoto photo;
  final Future<BuildingPhotoData> future;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BuildingPhotoData>(
      future: future,
      builder: (
        BuildContext context,
        AsyncSnapshot<BuildingPhotoData> snapshot,
      ) {
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
              onTap: () => _showPhotoDialog(context, photo, data),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: Image.memory(
                      data.bytes,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (
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

  void _showPhotoDialog(
    BuildContext context,
    BuildingPhoto photo,
    BuildingPhotoData data,
  ) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              title: const Text('写真'),
              leading: IconButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close),
                tooltip: '閉じる',
              ),
            ),
            body: Column(
              children: <Widget>[
                Expanded(
                  child: ColoredBox(
                    color: Colors.black,
                    child: Center(
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 5,
                        child: Image.memory(data.bytes, fit: BoxFit.contain),
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
                      Text(_formatDateTime(photo.takenAt ?? photo.createdAt)),
                      Text(_formatBytes(photo.byteSize)),
                      if (photo.width != null && photo.height != null)
                        Text('${photo.width} × ${photo.height}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VisitHistorySection extends StatelessWidget {
  const _VisitHistorySection({required this.detail, required this.tagsById});

  final BuildingDetailData detail;
  final Map<String, BuildingTag> tagsById;

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
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _VisitCard extends StatelessWidget {
  const _VisitCard({
    required this.visit,
    required this.photoCount,
    required this.tagsById,
  });

  final BuildingVisit visit;
  final int photoCount;
  final Map<String, BuildingTag> tagsById;

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
        ],
      ),
    );
  }
}

class _MetadataText extends StatelessWidget {
  const _MetadataText({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 17),
        const SizedBox(width: 4),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _SectionEmptyState extends StatelessWidget {
  const _SectionEmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            size: 44,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _DetailErrorState extends StatelessWidget {
  const _DetailErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline,
              size: 52,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('もう一度取得'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineErrorMessage extends StatelessWidget {
  const _InlineErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            const Icon(Icons.error_outline),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime? value) {
  if (value == null) {
    return '日時不明';
  }
  final DateTime local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}/${two(local.month)}/${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}

String _locationSourceLabel(String source) {
  return switch (source) {
    'gps' => 'GPS',
    'manual' => '手動指定',
    'building_fallback' => '建物代表位置',
    'test' => 'テスト位置',
    _ => source,
  };
}
