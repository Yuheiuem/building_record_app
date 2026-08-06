import 'package:building_record_app/core/config/app_config.dart';
import 'package:building_record_app/data/models/bootstrap_data.dart';
import 'package:building_record_app/data/models/building.dart';
import 'package:building_record_app/data/models/building_tag.dart';
import 'package:building_record_app/data/services/auth_service.dart';
import 'package:building_record_app/data/services/bootstrap_api_service.dart';
import 'package:building_record_app/features/browse/presentation/browse_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('建物を地図範囲の一覧へ表示し検索と再取得ができる', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);

    final _FakeAuthService authService = _FakeAuthService();
    final _FakeBootstrapApiService apiService = _FakeBootstrapApiService();
    Building? openedBuilding;

    await tester.pumpWidget(
      MaterialApp(
        home: BrowsePage(
          authService: authService,
          bootstrapApiService: apiService,
          enableNetworkTiles: false,
          onOpenBuilding: (Building building) {
            openedBuilding = building;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(apiService.callCount, 1);
    expect(apiService.lastIdToken, 'test-id-token');
    expect(find.text('建物地図'), findsOneWidget);
    expect(find.text(AppConfig.version), findsOneWidget);
    expect(find.byKey(const Key('browse-map-north')), findsOneWidget);
    expect(find.byKey(const Key('browse-map-zoom-in')), findsOneWidget);
    expect(find.byKey(const Key('browse-map-zoom-out')), findsOneWidget);
    expect(find.byType(Scalebar), findsOneWidget);
    expect(find.text('地図表示範囲 2件'), findsOneWidget);
    expect(find.text('座標あり 2件'), findsOneWidget);
    expect(find.text('座標なし 1件'), findsOneWidget);
    expect(find.text('北の建物'), findsOneWidget);
    expect(find.text('南の建物'), findsOneWidget);
    expect(find.text('国土地理院'), findsOneWidget);
    expect(find.text('設計第一部'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('browse-building-icon-north')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('browse-cover-photo-image-north')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('browse-building-north')),
    );
    await tester.pump();
    expect(openedBuilding?.buildingId, 'north');

    await tester.enterText(
      find.byKey(const Key('browse-building-search')),
      '南',
    );
    await tester.pump();

    expect(find.text('北の建物'), findsNothing);
    expect(find.text('南の建物'), findsOneWidget);
    expect(find.text('地図表示範囲 1件'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('browse-building-search')), '');
    await tester.pump();

    await tester.tap(find.byKey(const Key('refresh-browse-data')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(apiService.callCount, 2);
  });
}

class _FakeAuthService extends AuthService {
  @override
  GoogleAuthStatus get status => GoogleAuthStatus.signedIn;

  @override
  AuthenticatedGoogleUser get currentUser =>
      const AuthenticatedGoogleUser(email: 'test@example.com');

  @override
  String get idToken => 'test-id-token';

  @override
  String? get errorMessage => null;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> signOut() async {}
}

class _FakeBootstrapApiService implements BootstrapApiService {
  int callCount = 0;
  String? lastIdToken;

  @override
  Future<BootstrapData> getBootstrapData({
    required String requestId,
    required String clientVersion,
    required String idToken,
  }) async {
    callCount += 1;
    lastIdToken = idToken;

    return BootstrapData(
      requestId: requestId,
      serverTime: DateTime.parse('2026-07-30T14:30:00+09:00'),
      schemaVersion: '1.0',
      stage: '4-1',
      buildings: <Building>[
        _building(
          id: 'north',
          name: '北の建物',
          latitude: 35.72,
          longitude: 139.70,
          address: '東京都北区',
          designTags: const <String>['tag-design-1'],
          coverPhotoId: 'photo-cover-north',
        ),
        _building(
          id: 'south',
          name: '南の建物',
          latitude: 35.64,
          longitude: 139.70,
          address: '東京都品川区',
        ),
        _building(
          id: 'missing',
          name: '座標なしの建物',
          latitude: null,
          longitude: null,
        ),
      ],
      tags: const <BuildingTag>[
        BuildingTag(
          tagId: 'tag-design-1',
          tagType: BuildingTagType.design,
          tagName: '設計第一部',
          normalizedName: '設計第一部',
          displayOrder: 10,
          isActive: true,
          createdAt: null,
          updatedAt: null,
        ),
      ],
      counts: const BootstrapCounts(
        buildings: 3,
        visits: 4,
        photos: 5,
        tags: 1,
      ),
    );
  }

  @override
  void close() {}
}

Building _building({
  required String id,
  required String name,
  required double? latitude,
  required double? longitude,
  String? address,
  List<String> designTags = const <String>[],
  String? coverPhotoId,
}) {
  return Building(
    buildingId: id,
    buildingName: name,
    searchName: name,
    latitude: latitude,
    longitude: longitude,
    address: address,
    designTags: designTags,
    salesTags: const <String>[],
    constructionTags: const <String>[],
    driveFolderId: null,
    coverPhotoId: coverPhotoId,
    createdAt: null,
    updatedAt: null,
    isDeleted: false,
  );
}
