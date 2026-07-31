import 'dart:async';

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
import '../../../shared/widgets/authenticated_app_bar.dart';
import '../domain/browse_map_logic.dart';

class BrowsePage extends StatefulWidget {
  const BrowsePage({
    required this.authService,
    this.bootstrapApiService,
    this.enableNetworkTiles = true,
    this.onOpenBuilding,
    super.key,
  });

  final AuthService authService;
  final BootstrapApiService? bootstrapApiService;
  final bool enableNetworkTiles;
  final ValueChanged<Building>? onOpenBuilding;

  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<BrowsePage> {
  static const Duration _mapUpdateDelay = Duration(milliseconds: 250);

  late final BootstrapApiService _bootstrapApiService;
  late final bool _ownsBootstrapApiService;

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
        _isLoading = false;
        _mapRevision += 1;
      });
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
              },
            );

            final Widget workspace = _BrowseWorkspace(
              wideLayout: wideLayout,
              hasLoadedData: data != null,
              coordinateBuildings: coordinateData,
              markerBuildings: _markerBuildings,
              visibleBuildings: shownBuildings,
              tagsById: tagsById,
              visibleBounds: _visibleBounds,
              mapRevision: _mapRevision,
              enableNetworkTiles: widget.enableNetworkTiles,
              onPositionChanged: _handleMapPositionChanged,
              onOpenBuilding: _openBuilding,
            );

            if (wideLayout) {
              return Padding(
                padding: pagePadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    toolbar,
                    const SizedBox(height: 12),
                    Expanded(child: workspace),
                    const SizedBox(height: 12),
                    const AppVersionFooter(),
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
                  const SizedBox(height: 20),
                  const AppVersionFooter(),
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

class _BuildingMap extends StatelessWidget {
  const _BuildingMap({
    required this.allBuildings,
    required this.markerBuildings,
    required this.showLabels,
    required this.enableNetworkTiles,
    required this.onPositionChanged,
    super.key,
  });

  static const LatLng _fallbackCenter = LatLng(35.681236, 139.767125);

  final List<Building> allBuildings;
  final List<Building> markerBuildings;
  final bool showLabels;
  final bool enableNetworkTiles;
  final void Function(MapCamera camera, bool hasGesture) onPositionChanged;

  @override
  Widget build(BuildContext context) {
    final List<LatLng> points = allBuildings
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

    return Stack(
      children: <Widget>[
        FlutterMap(
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: points.length == 1 ? 16 : 11,
            initialCameraFit: initialCameraFit,
            minZoom: 5,
            maxZoom: 19,
            onPositionChanged: onPositionChanged,
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
              markers: markerBuildings
                  .map(
                    (Building building) => _buildingMarker(
                      context,
                      building,
                      showLabels: showLabels,
                    ),
                  )
                  .toList(growable: false),
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
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text('ピンは選択せず、右の一覧から確認します。'),
              ),
            ),
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

class _VisibleBuildingListCard extends StatelessWidget {
  const _VisibleBuildingListCard({
    required this.buildings,
    required this.tagsById,
    required this.fillAvailableHeight,
    required this.onOpenBuilding,
  });

  final List<Building> buildings;
  final Map<String, BuildingTag> tagsById;
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

class _BuildingListItem extends StatelessWidget {
  const _BuildingListItem({
    required this.building,
    required this.tagsById,
    required this.onOpenBuilding,
  });

  final Building building;
  final Map<String, BuildingTag> tagsById;
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
              Icon(Icons.apartment_outlined, color: colorScheme.primary),
              const SizedBox(width: 10),
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
