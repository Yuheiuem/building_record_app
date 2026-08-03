import 'package:building_record_app/data/models/record_draft_location.dart';
import 'package:building_record_app/data/services/record_location_service.dart';
import 'package:building_record_app/features/record/presentation/map_location_picker_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('初期座標がある場合は代表座標を中心にし現在地を取得しない', (
    WidgetTester tester,
  ) async {
    final _FakeRecordLocationService locationService =
        _FakeRecordLocationService(
          RecordDraftLocation(
            latitude: 35.700001,
            longitude: 139.700002,
            accuracyM: 5,
            source: RecordLocationSource.gps,
            capturedAt: DateTime(2026, 8, 3, 14),
          ),
        );
    RecordDraftLocation? selectedLocation;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async {
                    selectedLocation = await Navigator.of(context)
                        .push<RecordDraftLocation>(
                          MaterialPageRoute<RecordDraftLocation>(
                            builder: (BuildContext context) {
                              return MapLocationPickerPage(
                                initialLatitude: 35.689592,
                                initialLongitude: 139.691712,
                                locationService: locationService,
                                enableNetworkTiles: false,
                              );
                            },
                          ),
                        );
                  },
                  child: const Text('開く'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();

    expect(locationService.callCount, 0);
    expect(find.byKey(const Key('map-center-crosshair')), findsOneWidget);
    expect(find.text('緯度 35.689592'), findsOneWidget);
    expect(find.text('経度 139.691712'), findsOneWidget);

    final FlutterMap map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.options.initialRotation, 0);
    expect(
      InteractiveFlag.hasRotate(map.options.interactionOptions.flags),
      isFalse,
    );

    await tester.tap(find.byKey(const Key('confirm-map-location')));
    await tester.pumpAndSettle();

    expect(selectedLocation, isNotNull);
    expect(selectedLocation!.latitude, 35.689592);
    expect(selectedLocation!.longitude, 139.691712);
    expect(selectedLocation!.accuracyM, isNull);
    expect(selectedLocation!.source, RecordLocationSource.manual);
  });

  testWidgets('初期座標がない場合は現在地を中心に表示する', (
    WidgetTester tester,
  ) async {
    final _FakeRecordLocationService locationService =
        _FakeRecordLocationService(
          RecordDraftLocation(
            latitude: 35.700001,
            longitude: 139.700002,
            accuracyM: 5,
            source: RecordLocationSource.gps,
            capturedAt: DateTime(2026, 8, 3, 14),
          ),
        );
    RecordDraftLocation? selectedLocation;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async {
                    selectedLocation = await Navigator.of(context)
                        .push<RecordDraftLocation>(
                          MaterialPageRoute<RecordDraftLocation>(
                            builder: (BuildContext context) {
                              return MapLocationPickerPage(
                                locationService: locationService,
                                enableNetworkTiles: false,
                              );
                            },
                          ),
                        );
                  },
                  child: const Text('開く'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('開く'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(locationService.callCount, 1);
    expect(find.text('緯度 35.700001'), findsOneWidget);
    expect(find.text('経度 139.700002'), findsOneWidget);
    expect(
      find.byKey(const Key('map-current-location-loading')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('confirm-map-location')));
    await tester.pumpAndSettle();

    expect(selectedLocation, isNotNull);
    expect(selectedLocation!.latitude, 35.700001);
    expect(selectedLocation!.longitude, 139.700002);
    expect(selectedLocation!.source, RecordLocationSource.manual);
  });
}

class _FakeRecordLocationService implements RecordLocationService {
  _FakeRecordLocationService(this.location);

  final RecordDraftLocation location;
  int callCount = 0;

  @override
  Future<RecordDraftLocation> getCurrentLocation() async {
    callCount += 1;
    return location;
  }
}
