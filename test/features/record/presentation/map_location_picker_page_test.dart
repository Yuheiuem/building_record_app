import 'package:building_record_app/data/models/record_draft_location.dart';
import 'package:building_record_app/features/record/presentation/map_location_picker_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('中央座標を手動位置として返す', (WidgetTester tester) async {
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
                              return const MapLocationPickerPage(
                                initialLatitude: 35.689592,
                                initialLongitude: 139.691712,
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

    expect(find.byKey(const Key('map-center-crosshair')), findsOneWidget);
    expect(find.text('緯度 35.689592'), findsOneWidget);
    expect(find.text('経度 139.691712'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-map-location')));
    await tester.pumpAndSettle();

    expect(selectedLocation, isNotNull);
    expect(selectedLocation!.latitude, 35.689592);
    expect(selectedLocation!.longitude, 139.691712);
    expect(selectedLocation!.accuracyM, isNull);
    expect(selectedLocation!.source, RecordLocationSource.manual);
  });
}
