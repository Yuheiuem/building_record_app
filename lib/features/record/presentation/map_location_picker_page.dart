import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/app_config.dart';
import '../../../data/models/record_draft_location.dart';
import '../../../data/services/record_location_service.dart';

class MapLocationPickerPage extends StatefulWidget {
  const MapLocationPickerPage({
    this.initialLatitude,
    this.initialLongitude,
    this.locationService,
    this.enableNetworkTiles = true,
    super.key,
  });

  final double? initialLatitude;
  final double? initialLongitude;
  final RecordLocationService? locationService;
  final bool enableNetworkTiles;

  @override
  State<MapLocationPickerPage> createState() => _MapLocationPickerPageState();
}

class _MapLocationPickerPageState extends State<MapLocationPickerPage> {
  final MapController _mapController = MapController();

  late final RecordLocationService _locationService;
  late LatLng _center;
  late bool _isResolvingInitialLocation;
  String? _initialLocationError;

  bool get _hasInitialCoordinates =>
      widget.initialLatitude != null && widget.initialLongitude != null;

  @override
  void initState() {
    super.initState();
    _locationService =
        widget.locationService ?? GeolocatorRecordLocationService();
    _center = LatLng(
      widget.initialLatitude ?? AppConfig.recordMapDefaultLatitude,
      widget.initialLongitude ?? AppConfig.recordMapDefaultLongitude,
    );
    _isResolvingInitialLocation = !_hasInitialCoordinates;

    if (_isResolvingInitialLocation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_loadCurrentLocation());
      });
    }
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final RecordDraftLocation location = await _locationService
          .getCurrentLocation();
      if (!mounted) {
        return;
      }

      final LatLng nextCenter = LatLng(location.latitude, location.longitude);
      setState(() {
        _center = nextCenter;
        _isResolvingInitialLocation = false;
        _initialLocationError = null;
      });
      _mapController.move(nextCenter, AppConfig.recordMapDefaultZoom);
    } on RecordLocationException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isResolvingInitialLocation = false;
        _initialLocationError = '${error.message} 東京駅付近を表示します。';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isResolvingInitialLocation = false;
        _initialLocationError = '現在地を取得できませんでした。東京駅付近を表示します。';
      });
    }
  }

  void _handlePositionChanged(MapCamera camera, bool hasGesture) {
    final LatLng nextCenter = camera.center;
    if (nextCenter == _center) {
      return;
    }
    setState(() {
      _center = nextCenter;
    });
  }

  void _useCurrentCenter() {
    Navigator.of(context).pop(
      RecordDraftLocation(
        latitude: _center.latitude,
        longitude: _center.longitude,
        accuracyM: null,
        source: RecordLocationSource.manual,
        capturedAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('地図で位置を指定')),
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _center,
                  initialZoom: AppConfig.recordMapDefaultZoom,
                  initialRotation: 0,
                  minZoom: 5,
                  maxZoom: 19,
                  interactionOptions: InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    cursorKeyboardRotationOptions:
                        CursorKeyboardRotationOptions.disabled(),
                  ),
                  onPositionChanged: _handlePositionChanged,
                ),
                children: <Widget>[
                  if (widget.enableNetworkTiles)
                    TileLayer(
                      urlTemplate:
                          'https://cyberjapandata.gsi.go.jp/xyz/pale/{z}/{x}/{y}.png',
                      maxNativeZoom: 18,
                      userAgentPackageName: 'building_record_app',
                    ),
                  const SimpleAttributionWidget(source: Text('国土地理院')),
                ],
              ),
            ),
            const Center(
              child: IgnorePointer(
                child: _CenterCrosshair(key: Key('map-center-crosshair')),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Text(
                          '地図を動かし、建物の位置を中央の十字に合わせてください。',
                          textAlign: TextAlign.center,
                        ),
                        if (_isResolvingInitialLocation) ...<Widget>[
                          const SizedBox(height: 8),
                          const Row(
                            key: Key('map-current-location-loading'),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('現在地を取得しています。'),
                            ],
                          ),
                        ] else if (_initialLocationError != null) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(
                            _initialLocationError!,
                            key: const Key('map-current-location-error'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colors.error),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: SafeArea(
                top: false,
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          '中央の座標',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '緯度 ${_center.latitude.toStringAsFixed(6)}',
                          key: const Key('map-center-latitude'),
                        ),
                        Text(
                          '経度 ${_center.longitude.toStringAsFixed(6)}',
                          key: const Key('map-center-longitude'),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton(
                                key: const Key('cancel-map-location'),
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('キャンセル'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                key: const Key('confirm-map-location'),
                                onPressed: _isResolvingInitialLocation
                                    ? null
                                    : _useCurrentCenter,
                                icon: const Icon(Icons.check_outlined),
                                label: const Text('この位置を使う'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterCrosshair extends StatelessWidget {
  const _CenterCrosshair({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surface.withValues(alpha: 0.92),
        border: Border.all(color: colors.primary, width: 2),
        boxShadow: const <BoxShadow>[
          BoxShadow(blurRadius: 6, color: Colors.black26),
        ],
      ),
      child: SizedBox.square(
        dimension: 54,
        child: Icon(Icons.add, size: 42, color: colors.primary),
      ),
    );
  }
}
