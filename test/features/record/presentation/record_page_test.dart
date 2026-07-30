import 'dart:convert';
import 'dart:typed_data';

import 'package:building_record_app/data/models/bootstrap_data.dart';
import 'package:building_record_app/data/models/building.dart';
import 'package:building_record_app/data/models/building_tag.dart';
import 'package:building_record_app/data/models/record_draft_location.dart';
import 'package:building_record_app/data/models/record_draft_photo.dart';
import 'package:building_record_app/data/models/tag_creation_result.dart';
import 'package:building_record_app/data/services/auth_service.dart';
import 'package:building_record_app/data/services/bootstrap_api_service.dart';
import 'package:building_record_app/data/services/record_image_picker_service.dart';
import 'package:building_record_app/data/services/record_location_service.dart';
import 'package:building_record_app/data/services/tag_api_service.dart';
import 'package:building_record_app/features/record/presentation/record_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('初期状態では写真・建物・訪問の入力欄を表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RecordPage(
          authService: _FakeAuthService(),
          imagePickerService: const _FakeRecordImagePickerService(
            <RecordDraftPhoto>[],
          ),
          bootstrapApiService: _FakeBootstrapApiService(_emptyBootstrapData()),
          locationService: _FakeRecordLocationService(_gpsLocation()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('写真の下書き'), findsOneWidget);
    expect(find.text('写真がまだ選択されていません'), findsOneWidget);
    expect(find.text('建物の指定'), findsOneWidget);
    expect(find.byKey(const Key('new-building-name-field')), findsOneWidget);
    expect(find.text('今回の訪問'), findsOneWidget);
    expect(find.byKey(const Key('visit-impression-field')), findsOneWidget);
    expect(find.byKey(const Key('capture-current-location')), findsOneWidget);
    expect(find.text('段階 3-4B / v0.13.2'), findsOneWidget);
  });

  testWidgets('複数写真を選択して個別に削除できる', (WidgetTester tester) async {
    final List<RecordDraftPhoto> photos = <RecordDraftPhoto>[
      RecordDraftPhoto(
        photoId: 'photo-1',
        fileName: 'one.png',
        mimeType: 'image/png',
        bytes: _onePixelPng,
      ),
      RecordDraftPhoto(
        photoId: 'photo-2',
        fileName: 'two.png',
        mimeType: 'image/png',
        bytes: _onePixelPng,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: RecordPage(
          authService: _FakeAuthService(),
          imagePickerService: _FakeRecordImagePickerService(photos),
          bootstrapApiService: _FakeBootstrapApiService(_emptyBootstrapData()),
          locationService: _FakeRecordLocationService(_gpsLocation()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('select-record-photos')));
    await tester.pumpAndSettle();

    expect(find.text('2枚'), findsOneWidget);
    expect(find.text('one.png'), findsOneWidget);
    expect(find.text('two.png'), findsOneWidget);

    final Finder removeButton = find.byKey(
      const Key('remove-draft-photo-photo-1'),
    );
    expect(removeButton, findsOneWidget);
    await tester.ensureVisible(removeButton);
    await tester.pumpAndSettle();
    await tester.tap(removeButton);
    await tester.pumpAndSettle();

    expect(find.text('1枚'), findsOneWidget);
    expect(find.text('one.png'), findsNothing);
    expect(find.text('two.png'), findsOneWidget);
  });

  testWidgets('建物モードを切り替えても選択済み写真を保持する', (WidgetTester tester) async {
    final RecordDraftPhoto photo = RecordDraftPhoto(
      photoId: 'photo-1',
      fileName: 'one.png',
      mimeType: 'image/png',
      bytes: _onePixelPng,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RecordPage(
          authService: _FakeAuthService(),
          imagePickerService: _FakeRecordImagePickerService(<RecordDraftPhoto>[
            photo,
          ]),
          bootstrapApiService: _FakeBootstrapApiService(_bootstrapData()),
          locationService: _FakeRecordLocationService(_gpsLocation()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('select-record-photos')));
    await tester.pumpAndSettle();
    expect(find.text('1枚'), findsOneWidget);

    final Finder existingMode = find.byKey(
      const Key('record-building-mode-existing'),
    );
    await tester.ensureVisible(existingMode);
    await tester.tap(existingMode);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('existing-building-search-field')),
      findsOneWidget,
    );
    expect(find.text('1枚'), findsOneWidget);

    final Finder newMode = find.byKey(const Key('record-building-mode-new'));
    await tester.ensureVisible(newMode);
    await tester.tap(newMode);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('new-building-name-field')), findsOneWidget);
    expect(find.text('1枚'), findsOneWidget);
  });

  testWidgets('既存建物を選ぶと建物タグを読み取り専用で表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RecordPage(
          authService: _FakeAuthService(),
          imagePickerService: const _FakeRecordImagePickerService(
            <RecordDraftPhoto>[],
          ),
          bootstrapApiService: _FakeBootstrapApiService(_bootstrapData()),
          locationService: _FakeRecordLocationService(_gpsLocation()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder existingMode = find.byKey(
      const Key('record-building-mode-existing'),
    );
    await tester.ensureVisible(existingMode);
    await tester.tap(existingMode);
    await tester.pumpAndSettle();

    final Finder buildingOption = find.byKey(
      const Key('existing-building-option-building-1'),
    );
    await tester.ensureVisible(buildingOption);
    await tester.tap(buildingOption);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('selected-existing-building-panel')),
      findsOneWidget,
    );
    expect(find.text('第一ビル'), findsWidgets);
    expect(find.text('設計第一室'), findsOneWidget);
    expect(find.text('営業第一部'), findsOneWidget);
    expect(find.text('当社施工'), findsOneWidget);
    expect(find.text('登録済みタグの削除・変更はできません。追加するタグは下で選べます。'), findsOneWidget);
  });

  testWidgets('きっかけタグと感想を入力し現在地を取得できる', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RecordPage(
          authService: _FakeAuthService(),
          imagePickerService: const _FakeRecordImagePickerService(
            <RecordDraftPhoto>[],
          ),
          bootstrapApiService: _FakeBootstrapApiService(_bootstrapData()),
          locationService: _FakeRecordLocationService(_gpsLocation()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder triggerSelector = find.byKey(
      const PageStorageKey<String>('tag-selector-trigger'),
    );
    await tester.ensureVisible(triggerSelector);
    await tester.tap(triggerSelector);
    await tester.pumpAndSettle();

    final Finder triggerChip = find.byKey(
      const Key('visit-trigger-tag-tag-trigger-1'),
    );
    await tester.ensureVisible(triggerChip);
    await tester.tap(triggerChip);
    await tester.pumpAndSettle();

    final Finder impressionField = find.byKey(
      const Key('visit-impression-field'),
    );
    await tester.enterText(impressionField, '外観の素材が印象的だった。');

    final Finder locationButton = find.byKey(
      const Key('capture-current-location'),
    );
    await tester.ensureVisible(locationButton);
    await tester.tap(locationButton);
    await tester.pumpAndSettle();

    final FilterChip chip = tester.widget<FilterChip>(triggerChip);
    expect(chip.selected, isTrue);
    expect(find.text('外観の素材が印象的だった。'), findsOneWidget);
    expect(find.byKey(const Key('visit-location-value')), findsOneWidget);
    expect(find.text('端末の現在地'), findsOneWidget);
    expect(find.text('35.681236'), findsOneWidget);
    expect(find.text('139.767125'), findsOneWidget);
    expect(find.text('±8.4 m'), findsOneWidget);
  });

  testWidgets('既存建物の代表位置を下書きへ利用できる', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RecordPage(
          authService: _FakeAuthService(),
          imagePickerService: const _FakeRecordImagePickerService(
            <RecordDraftPhoto>[],
          ),
          bootstrapApiService: _FakeBootstrapApiService(_bootstrapData()),
          locationService: _FakeRecordLocationService(_gpsLocation()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder existingMode = find.byKey(
      const Key('record-building-mode-existing'),
    );
    await tester.ensureVisible(existingMode);
    await tester.tap(existingMode);
    await tester.pumpAndSettle();

    final Finder buildingOption = find.byKey(
      const Key('existing-building-option-building-1'),
    );
    await tester.ensureVisible(buildingOption);
    await tester.tap(buildingOption);
    await tester.pumpAndSettle();

    final Finder fallbackButton = find.byKey(
      const Key('use-building-location'),
    );
    await tester.ensureVisible(fallbackButton);
    await tester.tap(fallbackButton);
    await tester.pumpAndSettle();

    expect(find.text('建物の代表位置'), findsOneWidget);
    expect(find.text('未設定'), findsOneWidget);
  });
  testWidgets('タグ候補は折りたたみ、選択後は要約へ表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RecordPage(
          authService: _FakeAuthService(),
          imagePickerService: const _FakeRecordImagePickerService(
            <RecordDraftPhoto>[],
          ),
          bootstrapApiService: _FakeBootstrapApiService(_bootstrapData()),
          locationService: _FakeRecordLocationService(_gpsLocation()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder selector = find.byKey(
      const PageStorageKey<String>('tag-selector-trigger'),
    );
    await tester.ensureVisible(selector);
    await tester.tap(selector);
    await tester.pumpAndSettle();

    final Finder chip = find.byKey(
      const Key('visit-trigger-tag-tag-trigger-1'),
    );
    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('selected-tag-summary-trigger')),
      findsOneWidget,
    );
    expect(find.text('営業の仕事'), findsWidgets);
  });

  testWidgets('記録画面内でタグを追加して自動選択できる', (WidgetTester tester) async {
    final _FakeTagApiService tagService = _FakeTagApiService(
      TagCreationResult(
        tag: _tag(
          id: 'tag-trigger-new',
          type: BuildingTagType.trigger,
          name: '現場見学',
          order: 30,
        ),
        created: true,
        reactivated: false,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RecordPage(
          authService: _FakeAuthService(),
          imagePickerService: const _FakeRecordImagePickerService(
            <RecordDraftPhoto>[],
          ),
          bootstrapApiService: _FakeBootstrapApiService(_bootstrapData()),
          locationService: _FakeRecordLocationService(_gpsLocation()),
          tagApiService: tagService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder selector = find.byKey(
      const PageStorageKey<String>('tag-selector-trigger'),
    );
    await tester.ensureVisible(selector);
    await tester.tap(selector);
    await tester.pumpAndSettle();

    final Finder addButton = find.byKey(const Key('add-tag-trigger'));
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('new-tag-name-trigger')),
      '現場見学',
    );
    await tester.tap(find.byKey(const Key('submit-create-tag-trigger')));
    await tester.pumpAndSettle();

    expect(tagService.lastType, BuildingTagType.trigger);
    expect(tagService.lastName, '現場見学');
    expect(find.text('現場見学'), findsWidgets);
    expect(
      find.byKey(const Key('visit-trigger-tag-tag-trigger-new')),
      findsOneWidget,
    );
  });
}

final Uint8List _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9ZrV8AAAAASUVORK5CYII=',
);

RecordDraftLocation _gpsLocation() {
  return RecordDraftLocation(
    latitude: 35.681236,
    longitude: 139.767125,
    accuracyM: 8.4,
    source: RecordLocationSource.gps,
    capturedAt: DateTime.parse('2026-07-29T10:00:00+09:00'),
  );
}

BootstrapData _emptyBootstrapData() {
  return BootstrapData(
    requestId: 'request-empty',
    serverTime: DateTime.parse('2026-07-29T12:00:00+09:00'),
    schemaVersion: '1.0',
    stage: '2-2',
    buildings: const <Building>[],
    tags: const <BuildingTag>[],
    counts: const BootstrapCounts(buildings: 0, visits: 0, photos: 0, tags: 0),
  );
}

BootstrapData _bootstrapData() {
  return BootstrapData(
    requestId: 'request-1',
    serverTime: DateTime.parse('2026-07-29T12:00:00+09:00'),
    schemaVersion: '1.0',
    stage: '2-2',
    buildings: const <Building>[
      Building(
        buildingId: 'building-1',
        buildingName: '第一ビル',
        searchName: '第一ビル',
        latitude: 35.681236,
        longitude: 139.767125,
        address: '東京都千代田区',
        designTags: <String>['tag-design-1'],
        salesTags: <String>['tag-sales-1'],
        constructionTags: <String>['tag-con-1'],
        driveFolderId: null,
        coverPhotoId: null,
        createdAt: null,
        updatedAt: null,
        isDeleted: false,
      ),
    ],
    tags: <BuildingTag>[
      _tag(
        id: 'tag-trigger-1',
        type: BuildingTagType.trigger,
        name: '営業の仕事',
        order: 1,
      ),
      _tag(
        id: 'tag-trigger-2',
        type: BuildingTagType.trigger,
        name: '個人旅行',
        order: 2,
      ),
      _tag(
        id: 'tag-design-1',
        type: BuildingTagType.design,
        name: '設計第一室',
        order: 1,
      ),
      _tag(
        id: 'tag-sales-1',
        type: BuildingTagType.sales,
        name: '営業第一部',
        order: 1,
      ),
      _tag(
        id: 'tag-con-1',
        type: BuildingTagType.construction,
        name: '当社施工',
        order: 1,
      ),
    ],
    counts: const BootstrapCounts(buildings: 1, visits: 0, photos: 0, tags: 5),
  );
}

BuildingTag _tag({
  required String id,
  required BuildingTagType type,
  required String name,
  required int order,
}) {
  return BuildingTag(
    tagId: id,
    tagType: type,
    tagName: name,
    normalizedName: name,
    displayOrder: order,
    isActive: true,
    createdAt: null,
    updatedAt: null,
  );
}

class _FakeTagApiService implements TagApiService {
  _FakeTagApiService(this.result);

  final TagCreationResult result;
  BuildingTagType? lastType;
  String? lastName;

  @override
  Future<TagCreationResult> createTag({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required BuildingTagType tagType,
    required String tagName,
  }) async {
    lastType = tagType;
    lastName = tagName;
    return result;
  }

  @override
  void close() {}
}

class _FakeRecordImagePickerService implements RecordImagePickerService {
  const _FakeRecordImagePickerService(this.photos);

  final List<RecordDraftPhoto> photos;

  @override
  Future<List<RecordDraftPhoto>> pickImages() async => photos;
}

class _FakeBootstrapApiService implements BootstrapApiService {
  const _FakeBootstrapApiService(this.data);

  final BootstrapData data;

  @override
  Future<BootstrapData> getBootstrapData({
    required String requestId,
    required String clientVersion,
    required String idToken,
  }) async {
    return data;
  }

  @override
  void close() {}
}

class _FakeRecordLocationService implements RecordLocationService {
  const _FakeRecordLocationService(this.location);

  final RecordDraftLocation location;

  @override
  Future<RecordDraftLocation> getCurrentLocation() async => location;
}

class _FakeAuthService extends AuthService {
  @override
  GoogleAuthStatus get status => GoogleAuthStatus.signedIn;

  @override
  AuthenticatedGoogleUser get currentUser => const AuthenticatedGoogleUser(
    email: 'test@example.com',
    displayName: 'テスト利用者',
  );

  @override
  String get idToken => 'test-id-token';

  @override
  String? get errorMessage => null;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> signOut() async {}
}
