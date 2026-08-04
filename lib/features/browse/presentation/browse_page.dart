import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/routing/app_routes.dart';
import '../../../data/models/bootstrap_data.dart';
import '../../../data/models/building.dart';
import '../../../data/models/building_tag.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/bootstrap_api_service.dart';
import '../../../data/services/building_cover_photo_api_service.dart';
import '../../../shared/widgets/authenticated_app_bar.dart';
import '../domain/browse_map_logic.dart';

class BrowsePage extends StatefulWidget {
  const BrowsePage({
    required this.authService,
    this.bootstrapApiService,
    this.buildingCoverPhotoApiService,
    this.enableNetworkTiles = true,
    this.onOpenBuilding,
    super.key,
  });

  final AuthService authService;
  final BootstrapApiService? bootstrapApiService;
  final BuildingCoverPhotoApiService? buildingCoverPhotoApiService;
  final bool enableNetworkTiles;
  final ValueChanged<Building>? onOpenBuilding;

  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<BrowsePage> {
  static const Duration _mapUpdateDelay = Duration(milliseconds: 250);

  late final BootstrapApiService _bootstrapApiService;
  late final bool _ownsBootstrapApiService;
  late final BuildingCoverPhotoApiService _coverPhotoApiService;
  late final bool _ownsCoverPhotoApiService;

  final Map<String, BuildingCoverThumbnailData> _coverThumbnails =
      <String, BuildingCoverThumbnailData>{};
  final Set<String> _loadingCoverPhotoIds = <String>{};
  final Set<String> _failedCoverPhotoIds = <String>{};

  BootstrapData? _bootstrapData;
  BrowseMapBounds? _visibleBounds;
  String _searchQuery = '';
  String? _errorMessage;
  bool _isLoading = false;
  int _mapRevision = 0;
  Timer? _mapUpdateTimer;

  @override
  void initState() {
    super.initState();
    _ownsBootstrapApiService = widget.bootstrapApiService == null;
    _bootstrapApiService =
        widget.bootstrapApiService ?? HttpBootstrapApiService();
    _ownsCoverPhotoApiService = widget.buildingCoverPhotoApiService == null;
    _coverPhotoApiService =
        widget.buildingCoverPhotoApiService ??
        HttpBuildingCoverPhotoApiService();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBootstrapData();
    });
  }

  @override
  void dispose() {
    _mapUpdateTimer?.cancel();
    if (_ownsBootstrapApiService) {
      _bootstrapApiService.close();
    }
    if (_ownsCoverPhotoApiService) {
      _coverPhotoApiService.close();
    }
    super.dispose();
  }

  Future<void> _loadBootstrapData() async {
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
      final BootstrapData result = await _bootstrapApiService.getBootstrapData(
        requestId: const Uuid().v4(),
        clientVersion: AppConfig.version,
        idToken: idToken,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _bootstrapData = result;
        _visibleBounds = boundsForBuildings(result.buildings);
        _coverThumbnails.clear();
        _loadingCoverPhotoIds.clear();
        _failedCoverPhotoIds.clear();
        _isLoading = false;
        _mapRevision += 1;
      });
      _scheduleVisibleCoverThumbnailLoad();
    } on BootstrapApiException catch (error) {
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
        _errorMessage = 'データを取得できませんでした。もう一度送信してください。';
      });
    }
  }

  void _handleMapPositionChanged(MapCamera camera, bool hasGesture) {
    final LatLngBounds bounds = camera.visibleBounds;
    final BrowseMapBounds nextBounds = BrowseMapBounds(
      north: bounds.north,
      south: bounds.south,
      east: bounds.east,
      west: bounds.west,
    );

    _mapUpdateTimer?.cancel();
    _mapUpdateTimer = Timer(_mapUpdateDelay, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _visibleBounds = nextBounds;
      });
      _scheduleVisibleCoverThumbnailLoad();
    });
  }

  List<Building> get _allCoordinateBuildings {
    return coordinateBuildings(_bootstrapData?.buildings ?? const <Building>[]);
  }

  List<Building> get _visibleBuildings {
    final List<Building> baseBuildings = _visibleBounds == null
        ? _allCoordinateBuildings
        : visibleBuildings(_allCoordinateBuildings, _visibleBounds!);
    return filterBuildingsByQuery(baseBuildings, _searchQuery);
  }

  List<Building> get _markerBuildings {
    return filterBuildingsByQuery(_allCoordinateBuildings, _searchQuery);
  }

  int get _missingCoordinateCount {
    return (_bootstrapData?.buildings ?? const <Building>[])
        .where(
          (Building building) =>
              !building.isDeleted && !buildingHasCoordinates(building),
        )
        .length;
  }

  void _scheduleVisibleCoverThumbnailLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_loadVisibleCoverThumbnails());
    });
  }

  Future<void> _loadVisibleCoverThumbnails() async {
    final String? idToken = widget.authService.idToken;
    if (idToken == null || idToken.isEmpty) {
      return;
    }

    final List<String> pendingPhotoIds = _visibleBuildings
        .map((Building building) => building.coverPhotoId)
        .whereType<String>()
        .where((String photoId) => photoId.isNotEmpty)
        .where(
          (String photoId) =>
              !_coverThumbnails.containsKey(photoId) &&
              !_loadingCoverPhotoIds.contains(photoId) &&
              !_failedCoverPhotoIds.contains(photoId),
        )
        .toSet()
        .take(8)
        .toList(growable: false);
    if (pendingPhotoIds.isEmpty) {
      return;
    }

    setState(() {
      _loadingCoverPhotoIds.addAll(pendingPhotoIds);
    });

    try {
      final Map<String, BuildingCoverThumbnailData> result =
          await _coverPhotoApiService.getCoverPhotoThumbnails(
            requestId: const Uuid().v4(),
            clientVersion: AppConfig.version,
            idToken: idToken,
            photoIds: pendingPhotoIds,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _coverThumbnails.addAll(result);
        for (final String photoId in pendingPhotoIds) {
          if (!result.containsKey(photoId)) {
            _failedCoverPhotoIds.add(photoId);
          }
        }
      });
    } on BuildingCoverPhotoApiException {
      if (!mounted) {
        return;
      }
      setState(() {
        _failedCoverPhotoIds.addAll(pendingPhotoIds);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _failedCoverPhotoIds.addAll(pendingPhotoIds);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingCoverPhotoIds.removeAll(pendingPhotoIds);
        });
        _scheduleVisibleCoverThumbnailLoad();
      }
    }
  }

  void _retryCoverThumbnail(String photoId) {
    setState(() {
      _failedCoverPhotoIds.remove(photoId);
      _coverThumbnails.remove(photoId);
    });
    _scheduleVisibleCoverThumbnailLoad();
  }

  void _openBuilding(Building building) {
    final ValueChanged<Building>? callback = widget.onOpenBuilding;
    if (callback != null) {
      callback(building);
      return;
    }

    context.push(AppRoutes.buildingDetail(building.buildingId));
  }

  @override
  Widget build(BuildContext context) {
    final BootstrapData? data = _bootstrapData;
    final List<Building> coordinateData = _allCoordinateBuildings;
    final List<Building> shownBuildings = _visibleBuildings;
    final Map<String, BuildingTag> tagsById = <String, BuildingTag>{
      for (final BuildingTag tag in data?.tags ?? const <BuildingTag>[])
        tag.tagId: tag,
    };

    return Scaffold(
      appBar: AuthenticatedAppBar(
        authService: widget.authService,
        title: '地図・一覧で見る',
        showVersion: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool wideLayout = constraints.maxWidth >= 1000;
            final EdgeInsets pagePadding = EdgeInsets.symmetric(
              horizontal: wideLayout ? 24 : 12,
              vertical: 16,
            );

            final Widget toolbar = _BrowseToolbar(
              data: data,
              visibleCount: shownBuildings.length,
              coordinateCount: coordinateData.length,
              missingCoordinateCount: _missingCoordinateCount,
              errorMessage: _errorMessage,
              isLoading: _isLoading,
              onRefresh: _loadBootstrapData,
              onSearchChanged: (String value) {
                setState(() {
                  _searchQuery = value;
                });
                _scheduleVisibleCoverThumbnailLoad();
              },
            );

            final Widget workspace = _BrowseWorkspace(
              wideLayout: wideLayout,
              hasLoadedData: data != null,
              coordinateBuildings: coordinateData,
              markerBuildings: _markerBuildings,
              visibleBuildings: shownBuildings,
              tagsById: tagsById,
              coverThumbnails: _coverThumbnails,
              loadingCoverPhotoIds: _loadingCoverPhotoIds,
              failedCoverPhotoIds: _failedCoverPhotoIds,
              onRetryCoverPhoto: _retryCoverThumbnail,
              visibleBounds: _visibleBounds,
              mapRevision: _mapRevision,
              enableNetworkTiles: widget.enableNetworkTiles,
              onPositionChanged: _handleMapPositionChanged,
              onOpenBuilding: _openBuilding,
            );

            if (wideLayout) {
              final double workspaceHeight = math.max(
                680.0,
                constraints.maxHeight - 32.0,
              );

              return SingleChildScrollView(
                padding: pagePadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    toolbar,
                    const SizedBox(height: 12),
                    SizedBox(height: workspaceHeight, child: workspace),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  toolbar,
                  const SizedBox(height: 12),
                  workspace,
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BrowseToolbar extends StatelessWidget {
  const _BrowseToolbar({
    required this.data,
    required this.visibleCount,
    required this.coordinateCount,
    required this.missingCoordinateCount,
    required this.errorMessage,
    required this.isLoading,
    required this.onRefresh,
    required this.onSearchChanged,
  });

  final BootstrapData? data;
  final int visibleCount;
  final int coordinateCount;
  final int missingCoordinateCount;
  final String? errorMessage;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool compact = constraints.maxWidth < 720;
                final Widget heading = Row(
                  children: <Widget>[
                    Icon(
                      Icons.map_outlined,
                      color: colorScheme.primary,
                      size: 30,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '建物地図',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            data == null
                                ? 'Google Sheetsから建物を取得します。'
                                : '地図を動かすと、右の一覧を表示範囲に合わせて更新します。',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final Widget refreshButton = FilledButton.icon(
                  key: const Key('refresh-browse-data'),
                  onPressed: isLoading ? null : onRefresh,
                  icon: isLoading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(isLoading ? '取得中' : '最新データを取得'),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      heading,
                      const SizedBox(height: 12),
                      refreshButton,
                    ],
                  );
                }

                return Row(
                  children: <Widget>[
                    Expanded(child: heading),
                    const SizedBox(width: 16),
                    refreshButton,
                  ],
                );
              },
            ),
            if (errorMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              _BrowseErrorPanel(message: errorMessage!),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _BrowseCountChip(label: '地図表示範囲', count: visibleCount),
                _BrowseCountChip(label: '座標あり', count: coordinateCount),
                _BrowseCountChip(label: '座標なし', count: missingCoordinateCount),
                if (data != null)
                  _BrowseCountChip(label: '全建物', count: data!.counts.buildings),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('browse-building-search'),
              onChanged: onSearchChanged,
              decoration: const InputDecoration(
                labelText: '建物を検索',
                hintText: '建物名・検索名・住所',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrowseCountChip extends StatelessWidget {
  const _BrowseCountChip({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label $count件'));
  }
}

class _BrowseErrorPanel extends StatelessWidget {
  const _BrowseErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrowseWorkspace extends StatelessWidget {
  const _BrowseWorkspace({
    required this.wideLayout,
    required this.hasLoadedData,
    required this.coordinateBuildings,
    required this.markerBuildings,
    required this.visibleBuildings,
    required this.tagsById,
    required this.coverThumbnails,
    required this.loadingCoverPhotoIds,
    required this.failedCoverPhotoIds,
    required this.onRetryCoverPhoto,
    required this.visibleBounds,
    required this.mapRevision,
    required this.enableNetworkTiles,
    required this.onPositionChanged,
    required this.onOpenBuilding,
  });

  final bool wideLayout;
  final bool hasLoadedData;
  final List<Building> coordinateBuildings;
  final List<Building> markerBuildings;
  final List<Building> visibleBuildings;
  final Map<String, BuildingTag> tagsById;
  final Map<String, BuildingCoverThumbnailData> coverThumbnails;
  final Set<String> loadingCoverPhotoIds;
  final Set<String> failedCoverPhotoIds;
  final ValueChanged<String> onRetryCoverPhoto;
  final BrowseMapBounds? visibleBounds;
  final int mapRevision;
  final bool enableNetworkTiles;
  final void Function(MapCamera camera, bool hasGesture) onPositionChanged;
  final ValueChanged<Building> onOpenBuilding;

  @override
  Widget build(BuildContext context) {
    final Widget map = _BuildingMapCard(
      hasLoadedData: hasLoadedData,
      coordinateBuildings: coordinateBuildings,
      markerBuildings: markerBuildings,
      visibleBounds: visibleBounds,
      mapRevision: mapRevision,
      enableNetworkTiles: enableNetworkTiles,
      onPositionChanged: onPositionChanged,
    );
    final Widget list = _VisibleBuildingListCard(
      buildings: visibleBuildings,
      tagsById: tagsById,
      coverThumbnails: coverThumbnails,
      loadingCoverPhotoIds: loadingCoverPhotoIds,
      failedCoverPhotoIds: failedCoverPhotoIds,
      onRetryCoverPhoto: onRetryCoverPhoto,
      fillAvailableHeight: wideLayout,
      onOpenBuilding: onOpenBuilding,
    );

    if (wideLayout) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(flex: 2, child: map),
          const SizedBox(width: 12),
          Expanded(child: list),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(height: 430, child: map),
        const SizedBox(height: 12),
        list,
      ],
    );
  }
}

class _BuildingMapCard extends StatelessWidget {
  const _BuildingMapCard({
    required this.hasLoadedData,
    required this.coordinateBuildings,
    required this.markerBuildings,
    required this.visibleBounds,
    required this.mapRevision,
    required this.enableNetworkTiles,
    required this.onPositionChanged,
  });

  final bool hasLoadedData;
  final List<Building> coordinateBuildings;
  final List<Building> markerBuildings;
  final BrowseMapBounds? visibleBounds;
  final int mapRevision;
  final bool enableNetworkTiles;
  final void Function(MapCamera camera, bool hasGesture) onPositionChanged;

  @override
  Widget build(BuildContext context) {
    final bool showLabels =
        visibleBounds != null && shouldShowBuildingLabels(visibleBounds!);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: <Widget>[
                const Icon(Icons.public),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '地図',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(showLabels ? '建物名を表示' : 'ピンのみ'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: !hasLoadedData
                ? const _MapEmptyState(message: '建物データを取得すると地図を表示します。')
                : coordinateBuildings.isEmpty
                ? const _MapEmptyState(message: '座標が登録された建物はまだありません。')
                : _BuildingMap(
                    key: ValueKey<String>('browse-map-$mapRevision'),
                    allBuildings: coordinateBuildings,
                    markerBuildings: markerBuildings,
                    showLabels: showLabels,
                    enableNetworkTiles: enableNetworkTiles,
                    onPositionChanged: onPositionChanged,
                  ),
          ),
        ],
      ),
    );
  }
}

class _MapEmptyState extends StatelessWidget {
  const _MapEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.location_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _BuildingMap extends StatefulWidget {
  const _BuildingMap({
    required this.allBuildings,
    required this.markerBuildings,
    required this.showLabels,
    required this.enableNetworkTiles,
    required this.onPositionChanged,
    super.key,
  });

  final List<Building> allBuildings;
  final List<Building> markerBuildings;
  final bool showLabels;
  final bool enableNetworkTiles;
  final void Function(MapCamera camera, bool hasGesture) onPositionChanged;

  @override
  State<_BuildingMap> createState() => _BuildingMapState();
}

class _BuildingMapState extends State<_BuildingMap> {
  static const LatLng _fallbackCenter = LatLng(35.681236, 139.767125);
  static const double _minZoom = 5;
  static const double _maxZoom = 19;

  final MapController _mapController = MapController();

  void _changeZoom(double difference) {
    final MapCamera camera = _mapController.camera;
    final double nextZoom = (camera.zoom + difference)
        .clamp(_minZoom, _maxZoom)
        .toDouble();
    _mapController.move(camera.center, nextZoom);
  }

  void _resetNorth() {
    _mapController.rotate(0);
  }

  @override
  Widget build(BuildContext context) {
    final List<LatLng> points = widget.allBuildings
        .map(
          (Building building) =>
              LatLng(building.latitude!, building.longitude!),
        )
        .toList(growable: false);
    final LatLng initialCenter = points.isEmpty
        ? _fallbackCenter
        : points.first;
    final CameraFit? initialCameraFit = points.length >= 2
        ? CameraFit.coordinates(
            coordinates: points,
            padding: const EdgeInsets.all(48),
            maxZoom: 17,
          )
        : null;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: <Widget>[
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: points.length == 1 ? 16 : 11,
            initialCameraFit: initialCameraFit,
            minZoom: _minZoom,
            maxZoom: _maxZoom,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onPositionChanged: widget.onPositionChanged,
          ),
          children: <Widget>[
            if (widget.enableNetworkTiles)
              TileLayer(
                urlTemplate:
                    'https://cyberjapandata.gsi.go.jp/xyz/pale/{z}/{x}/{y}.png',
                maxNativeZoom: 18,
                userAgentPackageName: 'building_record_app',
              ),
            MarkerLayer(
              markers: widget.markerBuildings
                  .map(
                    (Building building) => _buildingMarker(
                      context,
                      building,
                      showLabels: widget.showLabels,
                    ),
                  )
                  .toList(growable: false),
            ),
            Scalebar(
              alignment: Alignment.bottomLeft,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 48),
              length: ScalebarLength.m,
              textStyle: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: const <Shadow>[
                  Shadow(color: Colors.white, blurRadius: 4),
                ],
              ),
            ),
            const SimpleAttributionWidget(source: Text('国土地理院')),
          ],
        ),
        Positioned(
          left: 10,
          top: 10,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text('ピンは選択せず、右の一覧から確認します。'),
              ),
            ),
          ),
        ),
        Positioned(
          right: 10,
          top: 10,
          child: _MapControlColumn(
            onResetNorth: _resetNorth,
            onZoomIn: () => _changeZoom(1),
            onZoomOut: () => _changeZoom(-1),
          ),
        ),
      ],
    );
  }

  Marker _buildingMarker(
    BuildContext context,
    Building building, {
    required bool showLabels,
  }) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Widget pin = Icon(
      Icons.location_on,
      size: 34,
      color: colorScheme.primary,
      shadows: const <Shadow>[Shadow(color: Colors.white, blurRadius: 4)],
    );

    if (!showLabels) {
      return Marker(
        point: LatLng(building.latitude!, building.longitude!),
        width: 42,
        height: 42,
        alignment: Alignment.bottomCenter,
        child: IgnorePointer(child: pin),
      );
    }

    return Marker(
      point: LatLng(building.latitude!, building.longitude!),
      width: 170,
      height: 76,
      alignment: Alignment.bottomCenter,
      child: IgnorePointer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              constraints: const BoxConstraints(maxWidth: 164),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Text(
                building.buildingName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            pin,
          ],
        ),
      ),
    );
  }
}

class _MapControlColumn extends StatelessWidget {
  const _MapControlColumn({
    required this.onResetNorth,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final VoidCallback onResetNorth;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
      elevation: 2,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _MapControlButton(
            key: const Key('browse-map-north'),
            tooltip: '北を上に戻す',
            onPressed: onResetNorth,
            child: const Text(
              'N',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const Divider(height: 1),
          _MapControlButton(
            key: const Key('browse-map-zoom-in'),
            tooltip: '地図を拡大',
            onPressed: onZoomIn,
            child: const Icon(Icons.add),
          ),
          const Divider(height: 1),
          _MapControlButton(
            key: const Key('browse-map-zoom-out'),
            tooltip: '地図を縮小',
            onPressed: onZoomOut,
            child: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.tooltip,
    required this.onPressed,
    required this.child,
    super.key,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox.square(dimension: 44, child: Center(child: child)),
      ),
    );
  }
}

class _VisibleBuildingListCard extends StatelessWidget {
  const _VisibleBuildingListCard({
    required this.buildings,
    required this.tagsById,
    required this.coverThumbnails,
    required this.loadingCoverPhotoIds,
    required this.failedCoverPhotoIds,
    required this.onRetryCoverPhoto,
    required this.fillAvailableHeight,
    required this.onOpenBuilding,
  });

  final List<Building> buildings;
  final Map<String, BuildingTag> tagsById;
  final Map<String, BuildingCoverThumbnailData> coverThumbnails;
  final Set<String> loadingCoverPhotoIds;
  final Set<String> failedCoverPhotoIds;
  final ValueChanged<String> onRetryCoverPhoto;
  final bool fillAvailableHeight;
  final ValueChanged<Building> onOpenBuilding;

  @override
  Widget build(BuildContext context) {
    final Widget listContent = buildings.isEmpty
        ? const _BuildingListEmptyState()
        : ListView.separated(
            key: const Key('visible-building-list'),
            shrinkWrap: !fillAvailableHeight,
            physics: fillAvailableHeight
                ? const ClampingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            itemCount: buildings.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(height: 8),
            itemBuilder: (BuildContext context, int index) {
              return _BuildingListItem(
                building: buildings[index],
                tagsById: tagsById,
                coverThumbnail: buildings[index].coverPhotoId == null
                    ? null
                    : coverThumbnails[buildings[index].coverPhotoId],
                isCoverThumbnailLoading:
                    buildings[index].coverPhotoId != null &&
                    loadingCoverPhotoIds.contains(
                      buildings[index].coverPhotoId,
                    ),
                didCoverThumbnailFail:
                    buildings[index].coverPhotoId != null &&
                    failedCoverPhotoIds.contains(buildings[index].coverPhotoId),
                onRetryCoverPhoto: buildings[index].coverPhotoId == null
                    ? null
                    : () => onRetryCoverPhoto(buildings[index].coverPhotoId!),
                onOpenBuilding: onOpenBuilding,
              );
            },
          );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: fillAvailableHeight ? MainAxisSize.max : MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: <Widget>[
                const Icon(Icons.format_list_bulleted),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '表示範囲の建物',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '北から順に表示しています。',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text('${buildings.length}件'),
              ],
            ),
          ),
          const Divider(height: 1),
          if (fillAvailableHeight)
            Expanded(child: listContent)
          else
            listContent,
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              '建物を選ぶと、詳細・訪問履歴・写真を開きます。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BuildingListEmptyState extends StatelessWidget {
  const _BuildingListEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.search_off_outlined,
            size: 42,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 10),
          const Text('現在の地図範囲または検索条件に合う建物はありません。', textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _BuildingCoverThumbnail extends StatelessWidget {
  const _BuildingCoverThumbnail({
    required this.buildingId,
    required this.hasCoverPhoto,
    required this.data,
    required this.isLoading,
    required this.didFail,
    required this.onRetry,
  });

  final String buildingId;
  final bool hasCoverPhoto;
  final BuildingCoverThumbnailData? data;
  final bool isLoading;
  final bool didFail;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    Widget child;
    if (data != null) {
      child = Image.memory(
        data!.bytes,
        key: ValueKey<String>('browse-cover-photo-image-$buildingId'),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) {
              return Icon(Icons.broken_image, color: colorScheme.primary);
            },
      );
    } else if (isLoading) {
      child = const Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else if (hasCoverPhoto && didFail) {
      child = IconButton(
        key: ValueKey<String>('retry-browse-cover-photo-$buildingId'),
        tooltip: '代表写真を再取得',
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
      );
    } else {
      child = Icon(
        Icons.apartment_outlined,
        color: colorScheme.primary,
        size: 32,
      );
    }

    return Container(
      key: ValueKey<String>('browse-cover-photo-$buildingId'),
      width: 72,
      height: 72,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Center(child: child),
    );
  }
}

class _BuildingListItem extends StatelessWidget {
  const _BuildingListItem({
    required this.building,
    required this.tagsById,
    required this.coverThumbnail,
    required this.isCoverThumbnailLoading,
    required this.didCoverThumbnailFail,
    required this.onRetryCoverPhoto,
    required this.onOpenBuilding,
  });

  final Building building;
  final Map<String, BuildingTag> tagsById;
  final BuildingCoverThumbnailData? coverThumbnail;
  final bool isCoverThumbnailLoading;
  final bool didCoverThumbnailFail;
  final VoidCallback? onRetryCoverPhoto;
  final ValueChanged<Building> onOpenBuilding;

  @override
  Widget build(BuildContext context) {
    final List<String> tagNames = _resolveTagNames(building, tagsById);
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Material(
      key: ValueKey<String>('browse-building-${building.buildingId}'),
      color: colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => onOpenBuilding(building),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _BuildingCoverThumbnail(
                buildingId: building.buildingId,
                hasCoverPhoto: building.coverPhotoId != null,
                data: coverThumbnail,
                isLoading: isCoverThumbnailLoading,
                didFail: didCoverThumbnailFail,
                onRetry: onRetryCoverPhoto,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      building.buildingName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (building.address != null) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        building.address!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (tagNames.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: tagNames
                            .map(
                              (String tagName) => Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text(tagName),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _resolveTagNames(
    Building building,
    Map<String, BuildingTag> tagsById,
  ) {
    final List<String> tagIds = <String>[
      ...building.designTags,
      ...building.salesTags,
      ...building.constructionTags,
    ];
    final List<String> names = <String>[];
    final Set<String> seen = <String>{};

    for (final String tagId in tagIds) {
      final String? name = tagsById[tagId]?.tagName;
      if (name != null && seen.add(name)) {
        names.add(name);
      }
    }
    return names;
  }
}
