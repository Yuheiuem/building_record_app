import 'dart:convert';
import 'dart:typed_data';

import 'package:building_record_app/data/models/bootstrap_data.dart';
import 'package:building_record_app/data/models/building.dart';
import 'package:building_record_app/data/models/building_tag.dart';
import 'package:building_record_app/data/models/record_draft_photo.dart';
import 'package:building_record_app/data/services/auth_service.dart';
import 'package:building_record_app/data/services/bootstrap_api_service.dart';
import 'package:building_record_app/data/services/record_image_picker_service.dart';
import 'package:building_record_app/features/record/presentation/record_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('初期状態では写真と新規建物の入力欄を表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RecordPage(
          authService: _FakeAuthService(),
          imagePickerService: const _FakeRecordImagePickerService(
            <RecordDraftPhoto>[],
          ),
          bootstrapApiService: _FakeBootstrapApiService(_emptyBootstrapData()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('写真の下書き'), findsOneWidget);
    expect(find.text('写真がまだ選択されていません'), findsOneWidget);
    expect(find.text('建物の指定'), findsOneWidget);
    expect(find.byKey(const Key('new-building-name-field')), findsOneWidget);
    expect(find.byKey(const Key('select-record-photos')), findsOneWidget);
    expect(find.text('段階 3-2 / v0.10.0'), findsOneWidget);
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
    expect(find.text('既存建物のタグはこの画面では変更できません。'), findsOneWidget);
  });
}

final Uint8List _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9ZrV8AAAAASUVORK5CYII=',
);

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
    buildings: <Building>[
      Building(
        buildingId: 'building-1',
        buildingName: '第一ビル',
        searchName: '第一ビル',
        latitude: null,
        longitude: null,
        address: '東京都千代田区',
        designTags: const <String>['設計第一室'],
        salesTags: const <String>['営業第一部'],
        constructionTags: const <String>['当社施工'],
        driveFolderId: null,
        coverPhotoId: null,
        createdAt: null,
        updatedAt: null,
        isDeleted: false,
      ),
    ],
    tags: <BuildingTag>[
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
    counts: const BootstrapCounts(buildings: 1, visits: 0, photos: 0, tags: 3),
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
